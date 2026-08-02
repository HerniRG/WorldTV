import Foundation

struct ChannelFeed: Identifiable, Hashable, Sendable {
    let id: String
    let channelID: String
    let name: String?
    let isMain: Bool
    let languages: [String]
    let broadcastArea: [String]
    let timezones: [String]
    let videoFormat: String?
    let altNames: [String]
}

extension ChannelFeed {
    var displayName: String {
        guard let name, !name.isEmpty else {
            return String(localized: "player.feed.auto")
        }
        return name
    }
}
