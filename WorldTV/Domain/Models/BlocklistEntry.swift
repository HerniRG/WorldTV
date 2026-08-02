import Foundation

struct BlocklistEntry: Identifiable, Hashable, Sendable {
    var id: String { channelID }

    let channelID: String
    let reason: String
    let ref: String
}