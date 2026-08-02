import Foundation

struct PlayerChannelInfo: Sendable {
    let name: String
    let broadcasterName: String
    let countryName: String
    let categoryNames: [String]
    let logoURL: URL?
    let feeds: [ChannelFeed]
}
