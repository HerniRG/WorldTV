import Foundation
import OSLog
#if os(tvOS)
import TVServices
#endif

struct TopShelfPayloadWriter: Sendable {
    private let repository: any ChannelRepository
    private let recentlyWatchedRepository: any RecentlyWatchedRepository
    private let favoritesRepository: any FavoritesRepository
    private let logger = Logger(subsystem: "hrgapps.WorldTV", category: "topShelf")

    init(
        repository: any ChannelRepository,
        recentlyWatchedRepository: any RecentlyWatchedRepository,
        favoritesRepository: any FavoritesRepository
    ) {
        self.repository = repository
        self.recentlyWatchedRepository = recentlyWatchedRepository
        self.favoritesRepository = favoritesRepository
    }

    func write() async {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: TopShelfConfiguration.appGroupIdentifier
            )
        else {
            logger.error("Top shelf App Group container is unavailable")
            return
        }
        do {
            let catalog = try await repository.loadCatalog()
            let history = (try? await recentlyWatchedRepository.load()) ?? []
            let favoriteIdentifiers = (try? await favoritesRepository.load()) ?? []

            let recent = await makeChannels(
                ids: history.map(\.channelID),
                catalog: catalog,
                container: container
            )
            let favorites = await makeChannels(
                ids: favoriteIdentifiers,
                catalog: catalog,
                container: container
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(
                TopShelfPayload(recent: recent, favorites: favorites)
            )
            let directory = container.appendingPathComponent(
                TopShelfConfiguration.payloadDirectory,
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let url = directory.appendingPathComponent(
                TopShelfConfiguration.payloadFileName
            )
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                // A payload left by an older installation can make an atomic
                // replacement fail on the persistent App Group container.
                // Retry a direct overwrite before reporting the App Group as
                // unusable.
                logger.error(
                    "Atomic top shelf write failed; retrying direct write: \(error.localizedDescription)"
                )
                try data.write(to: url)
            }
#if os(tvOS)
            TVTopShelfContentProvider.topShelfContentDidChange()
#endif
            logger.info(
                "Top shelf payload written: favorites=\(favorites.count), recent=\(recent.count), images=\(recent.filter { $0.logoURL != nil }.count + favorites.filter { $0.logoURL != nil }.count), container=\(container.path)"
            )
        } catch {
            logger.error("Top shelf payload could not be written: \(error.localizedDescription)")
        }
    }

    private func makeChannels(
        ids: [String],
        catalog: Catalog,
        container: URL
    ) async -> [TopShelfChannel] {
        var channels: [TopShelfChannel] = []
        for id in ids {
            guard let channel = catalog.index.channelsByID[id] else {
                continue
            }
            let logo = catalog.index.preferredLogoByChannelID[id]
            channels.append(
                TopShelfChannel(
                    id: channel.id,
                    name: channel.name,
                    logoURL: await tileURL(
                        for: logo,
                        channelID: channel.id,
                        container: container
                    )
                )
            )
        }
        return channels
    }

    private func tileURL(
        for logo: ChannelLogo?,
        channelID: String,
        container: URL
    ) async -> String? {
        guard let logo else {
            return nil
        }
        let directory = container
            .appendingPathComponent(
                TopShelfConfiguration.payloadDirectory,
                isDirectory: true
            )
            .appendingPathComponent("TopShelfImages", isDirectory: true)
        let fileURL = directory.appendingPathComponent("\(channelID).png")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL.absoluteString
        }
        guard
            let response = try? await URLSession.shared.data(from: logo.url),
            let tile = TopShelfArtworkRenderer.renderTile(logoData: response.0)
        else {
            return logo.url.absoluteString
        }
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try tile.write(to: fileURL, options: .atomic)
            return fileURL.absoluteString
        } catch {
            return logo.url.absoluteString
        }
    }
}
