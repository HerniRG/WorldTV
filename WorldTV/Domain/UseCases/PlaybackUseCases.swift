import Foundation

struct ResolvePlayableStreamUseCase: Sendable {
    private let repository: any ChannelRepository
    private let maximumAttempts: Int

    init(repository: any ChannelRepository, maximumAttempts: Int = 8) {
        self.repository = repository
        self.maximumAttempts = maximumAttempts
    }

    func execute(
        channelID: String,
        preferredQuality: Int? = nil,
        feedID: String? = nil
    ) async throws -> PlaybackContext {
        let catalog = try await repository.loadCatalog()
        guard let channel = catalog.index.channelsByID[channelID] else {
            throw PlaybackError.channelNotFound
        }

        var candidateStreams = catalog.streamsByChannelID[channelID] ?? []
        if let feedID {
            let feedStreams = candidateStreams.filter { $0.feed == feedID }
            if !feedStreams.isEmpty {
                candidateStreams = feedStreams
            }
        }

        let sources = candidateStreams
            .map(Self.makeSource)
            .sorted {
                Self.isPreferred(
                    $0,
                    $1,
                    preferredQuality: preferredQuality
                )
            }

        guard !sources.isEmpty else {
            throw PlaybackError.noSources
        }
        let categoriesByID = Dictionary(
            uniqueKeysWithValues: catalog.categories.map { ($0.id, $0) }
        )
        return PlaybackContext(
            channel: channel,
            feeds: catalog.index.feedsByChannelID[channelID] ?? [],
            sources: Array(sources.prefix(maximumAttempts)),
            logoURL: catalog.index.preferredLogoByChannelID[channelID]?.url,
            countryName: catalog.index.countryByCode[channel.countryCode]?.name ?? "",
            categoryNames: channel.categoryIDs.compactMap { categoriesByID[$0]?.name }
        )
    }

    private static func makeSource(_ stream: ChannelStream) -> PlaybackSource {
        PlaybackSource(
            url: stream.url,
            quality: stream.quality,
            title: stream.title,
            label: stream.label,
            referrer: stream.referrer,
            userAgent: stream.userAgent,
            isHLS: stream.url.pathExtension.lowercased() == "m3u8"
        )
    }

    private static func isPreferred(
        _ lhs: PlaybackSource,
        _ rhs: PlaybackSource,
        preferredQuality: Int?
    ) -> Bool {
        if lhs.isHLS != rhs.isHLS {
            return lhs.isHLS
        }

        let lhsQuality = qualityValue(lhs.quality)
        let rhsQuality = qualityValue(rhs.quality)
        if let preferredQuality {
            let lhsDistance = abs(lhsQuality - preferredQuality)
            let rhsDistance = abs(rhsQuality - preferredQuality)
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
        }
        if lhsQuality != rhsQuality {
            return lhsQuality > rhsQuality
        }

        return lhs.url.absoluteString < rhs.url.absoluteString
    }

    private static func qualityValue(_ quality: String?) -> Int {
        guard let quality else {
            return 0
        }
        return Int(quality.filter(\.isNumber)) ?? 0
    }
}

struct RecordRecentlyWatchedUseCase: Sendable {
    private let repository: any RecentlyWatchedRepository
    private let now: @Sendable () -> Date

    init(
        repository: any RecentlyWatchedRepository,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.repository = repository
        self.now = now
    }

    func execute(channelID: String) async {
        do {
            try await repository.record(channelID: channelID, at: now())
        } catch {
            // Playback must continue even if optional local history cannot be persisted.
        }
    }
}
