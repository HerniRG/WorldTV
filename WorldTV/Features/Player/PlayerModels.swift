import Foundation

struct PlayerChannelInfo: Sendable {
    let channelID: String
    let name: String
    let broadcasterName: String
    let countryName: String
    let categoryNames: [String]
    let logoURL: URL?
    let feeds: [ChannelFeed]
    let network: String?
    let launched: String?
}
