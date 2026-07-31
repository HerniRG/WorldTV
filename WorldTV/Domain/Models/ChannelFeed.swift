import Foundation

struct ChannelFeed: Identifiable, Hashable, Sendable {
    let id: String
    let channelID: String
    let name: String?
    let isMain: Bool
    let languages: [String]
}
