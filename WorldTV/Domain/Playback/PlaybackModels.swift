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

struct PlaybackContext: Sendable {
    let channel: Channel
    let feeds: [ChannelFeed]
    let sources: [PlaybackSource]
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

struct RecentlyWatchedChannel: Identifiable, Codable, Equatable, Sendable {
    var id: String { channelID }

    let channelID: String
    let watchedAt: Date
}
