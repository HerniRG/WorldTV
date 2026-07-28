import Foundation

protocol FavoritesRepository: Sendable {
    func load() async throws -> [String]
    func toggle(channelID: String) async throws -> Bool
    func clear() async throws
}
