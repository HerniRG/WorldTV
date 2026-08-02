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
        let availableFeeds = catalog.index.feedsByChannelID[channelID] ?? []
        
        // Auto-select feed based on locale if not explicitly provided
        let effectiveFeedID: String?
        if let feedID {
            effectiveFeedID = feedID
        } else if !availableFeeds.isEmpty {
            effectiveFeedID = Self.selectBestFeed(availableFeeds, for: channel, locale: Locale.current)
        } else {
            effectiveFeedID = nil
        }
        
        if let effectiveFeedID {
            let feedStreams = candidateStreams.filter { $0.feed == effectiveFeedID }
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
            feeds: availableFeeds,
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

    private static func selectBestFeed(_ feeds: [ChannelFeed], for channel: Channel, locale: Locale) -> String? {
        let regionCode = locale.region?.identifier ?? ""
        let languageCode = locale.language.languageCode?.identifier ?? ""
        
        // Priority 1: Feed matching user's region in broadcast_area
        for feed in feeds {
            if feed.broadcastArea.contains(regionCode) {
                return feed.id
            }
        }
        
        // Priority 2: Feed matching user's language
        for feed in feeds {
            if feed.languages.contains(languageCode) {
                return feed.id
            }
        }
        
        // Priority 3: Main feed
        for feed in feeds {
            if feed.isMain {
                return feed.id
            }
        }
        
        // Priority 4: First available feed
        return feeds.first?.id
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
