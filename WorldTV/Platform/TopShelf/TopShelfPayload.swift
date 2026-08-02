import Foundation

enum TopShelfConfiguration {
    static let appGroupIdentifier = "group.hrgapps.WorldTV"
    // Versioned to avoid a stale file left in the persistent App Group
    // container by an older signed installation.
    static let payloadFileName = "topShelf-v2.json"
}

struct TopShelfChannel: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let logoURL: String?
}

struct TopShelfPayload: Codable, Equatable, Sendable {
    var recent: [TopShelfChannel]
    var favorites: [TopShelfChannel]
}

extension Notification.Name {
    static let topShelfDataDidChange = Notification.Name(
        "hrgapps.worldtv.topShelfDataDidChange"
    )
}
