import Foundation

struct ResolvePlayableStreamUseCase: Sendable {
    private let repository: any ChannelRepository
    private let maximumAttempts: Int

    init(repository: any ChannelRepository, maximumAttempts: Int = 8) {
        self.repository = repository
        self.maximumAttempts = maximumAttempts
    }

    func execute(channelID: String) async throws -> PlaybackContext {
        let catalog = try await repository.loadCatalog()
        guard let channel = catalog.index.channelsByID[channelID] else {
            throw PlaybackError.channelNotFound
        }

        let sources = (catalog.streamsByChannelID[channelID] ?? [])
            .map(Self.makeSource)
            .sorted(by: Self.isPreferred)

        guard !sources.isEmpty else {
            throw PlaybackError.noSources
        }
        return PlaybackContext(channel: channel, sources: Array(sources.prefix(maximumAttempts)))
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

    private static func isPreferred(_ lhs: PlaybackSource, _ rhs: PlaybackSource) -> Bool {
        if lhs.isHLS != rhs.isHLS {
            return lhs.isHLS
        }

        let lhsQuality = qualityValue(lhs.quality)
        let rhsQuality = qualityValue(rhs.quality)
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
