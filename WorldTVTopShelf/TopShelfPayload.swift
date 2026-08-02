import Foundation

enum TopShelfConfiguration {
    static let appGroupIdentifier = "group.hrgapps.WorldTV"
    // On tvOS the root of an App Group container is not writable on a
    // physical device; only the subdirectories created by the system, such as
    // Library/Caches, are. The simulator is laxer, so root writes appear to
    // work there but fail with EACCES on an Apple TV.
    static let payloadDirectory = "Library/Caches"
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
