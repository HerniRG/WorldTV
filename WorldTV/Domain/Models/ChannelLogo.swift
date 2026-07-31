import Foundation

struct ChannelLogo: Identifiable, Hashable, Sendable {
    let id: URL
    let channelID: String
    let url: URL
    let feed: String?
    let width: Int?
    let height: Int?
    let format: String?
    let isInUse: Bool
    var tags: [String] = []
}
