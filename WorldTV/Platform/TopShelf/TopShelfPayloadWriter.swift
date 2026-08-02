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

            let recent = history.compactMap { entry in
                makeChannel(
                    catalog.index.channelsByID[entry.channelID],
                    logo: catalog.index.preferredLogoByChannelID[entry.channelID]
                )
            }
            let favorites = favoriteIdentifiers.compactMap { identifier in
                makeChannel(
                    catalog.index.channelsByID[identifier],
                    logo: catalog.index.preferredLogoByChannelID[identifier]
                )
            }

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

    private func makeChannel(
        _ channel: Channel?,
        logo: ChannelLogo?
    ) -> TopShelfChannel? {
        guard let channel else {
            return nil
        }
        return TopShelfChannel(
            id: channel.id,
            name: channel.name,
            logoURL: logo?.url.absoluteString
        )
    }
}
