import Foundation

struct PlaybackSource: Identifiable, Equatable, Sendable {
    var id: URL { url }

    let url: URL
    let quality: String?
    let title: String?
    let label: String?
    let referrer: String?
    let userAgent: String?
    let isHLS: Bool
}

struct PlaybackTimelineSnapshot: Equatable, Sendable {
    let position: TimeInterval?
    let duration: TimeInterval?
    let currentDate: Date?
    let seekableStart: TimeInterval?
    let seekableEnd: TimeInterval?
    let isLive: Bool
}

struct PlaybackContext: Sendable {
    let channel: Channel
    let feeds: [ChannelFeed]
    let sources: [PlaybackSource]
    let logoURL: URL?
    let countryName: String
    let categoryNames: [String]

    init(
        channel: Channel,
        feeds: [ChannelFeed],
        sources: [PlaybackSource],
        logoURL: URL? = nil,
        countryName: String = "",
        categoryNames: [String] = []
    ) {
        self.channel = channel
        self.feeds = feeds
        self.sources = sources
        self.logoURL = logoURL
        self.countryName = countryName
        self.categoryNames = categoryNames
    }
}

enum PlaybackError: Error, Equatable, Sendable {
    case channelNotFound
    case noSources
    case allSourcesFailed
    case unavailable
}

enum PlaybackState: Equatable, Sendable {
    case idle
    case resolving
    case preparing
    case playing
    case buffering
    case paused
    case failed(PlaybackError)
    case ended
}

enum PlaybackSessionState: Equatable, Sendable {
    case idle
    case preparing
    case playing
    case buffering
    case paused
    case ended
    case failed(PlaybackError)
}

enum PlaybackSessionEvent: Sendable {
    case readyToPlay
    case started
    case waiting
    case paused
    case sourceFailed
    case failed(PlaybackError)
    case ended
    case timeline(PlaybackTimelineSnapshot)
}

enum PlaybackSessionAction: Equatable, Sendable {
    case none
    case prepareSource(Int)
    case failed(PlaybackError)
    case ended
}

struct PlaybackSession: Sendable {
    let sources: [PlaybackSource]
    private(set) var currentSourceIndex = 0
    private(set) var state: PlaybackSessionState = .idle
    private(set) var timeline: PlaybackTimelineSnapshot?

    init(sources: [PlaybackSource]) {
        self.sources = sources
        timeline = nil
    }

    var currentSource: PlaybackSource? {
        guard sources.indices.contains(currentSourceIndex) else {
            return nil
        }
        return sources[currentSourceIndex]
    }

    mutating func start() -> PlaybackSessionAction {
        guard !sources.isEmpty else {
            state = .failed(.noSources)
            return .failed(.noSources)
        }
        state = .preparing
        return .prepareSource(currentSourceIndex)
    }

    mutating func handle(_ event: PlaybackSessionEvent) -> PlaybackSessionAction {
        switch event {
        case .readyToPlay:
            guard state == .preparing else {
                return .none
            }
            return .none
        case .started:
            guard state == .preparing || state == .buffering || state == .paused else {
                return .none
            }
            state = .playing
            return .none
        case .waiting:
            guard state == .playing || state == .preparing else {
                return .none
            }
            state = .buffering
            return .none
        case .paused:
            guard state == .preparing || state == .playing || state == .buffering else {
                return .none
            }
            state = .paused
            return .none
        case .sourceFailed:
            guard currentSourceIndex + 1 < sources.count else {
                state = .failed(.allSourcesFailed)
                return .failed(.allSourcesFailed)
            }
            currentSourceIndex += 1
            state = .preparing
            return .prepareSource(currentSourceIndex)
        case .failed(let error):
            state = .failed(error)
            return .failed(error)
        case .ended:
            state = .ended
            return .ended
        case .timeline(let snapshot):
            timeline = snapshot
            return .none
        }
    }

    mutating func retry() -> PlaybackSessionAction {
        currentSourceIndex = 0
        return start()
    }
}

struct RecentlyWatchedChannel: Identifiable, Codable, Equatable, Sendable {
    var id: String { channelID }

    let channelID: String
    let watchedAt: Date
}
