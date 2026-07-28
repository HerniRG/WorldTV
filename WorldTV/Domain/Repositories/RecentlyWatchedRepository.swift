import Foundation

protocol RecentlyWatchedRepository: Sendable {
    func load() async throws -> [RecentlyWatchedChannel]
    func record(channelID: String, at date: Date) async throws
    func clear() async throws
}
