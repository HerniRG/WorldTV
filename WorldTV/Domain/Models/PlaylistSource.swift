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
        case .invalidURL: String(localized: "sources.error.invalidURL")
        case .unsupportedURLScheme: String(localized: "sources.error.unsupportedScheme")
        case .emptyPlaylist: String(localized: "sources.error.emptyPlaylist")
        case .noPlayableEntries: String(localized: "sources.error.noPlayableEntries")
        }
    }
}
