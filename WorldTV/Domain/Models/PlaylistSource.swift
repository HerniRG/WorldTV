import Foundation

struct PlaylistSource: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    let url: URL
    let createdAt: Date

    init(id: UUID = UUID(), name: String, url: URL, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.url = url
        self.createdAt = createdAt
    }
}

enum PlaylistSourceError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case unsupportedURLScheme
    case emptyPlaylist
    case noPlayableEntries

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The source URL is invalid."
        case .unsupportedURLScheme: "Only HTTP and HTTPS playlist URLs are supported."
        case .emptyPlaylist: "The playlist is empty."
        case .noPlayableEntries: "The playlist does not contain playable entries."
        }
    }
}
