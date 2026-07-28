import Foundation

struct ChannelStream: Identifiable, Hashable, Sendable {
    let id: URL
    let channelID: String
    let url: URL
    let feed: String?
    let title: String?
    let quality: String?
    let label: String?
    let referrer: String?
    let userAgent: String?
}
