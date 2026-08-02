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

struct RecentlyWatchedChannel: Identifiable, Codable, Equatable, Sendable {
    var id: String { channelID }

    let channelID: String
    let watchedAt: Date
}
