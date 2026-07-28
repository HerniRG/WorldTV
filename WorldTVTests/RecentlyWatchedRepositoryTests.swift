import Foundation
import Testing
@testable import WorldTV

struct RecentlyWatchedRepositoryTests {
    @Test
    func newestChannelComesFirstWithoutDuplicates() async throws {
        let repository = makeRepository()
        await repository.clear()

        try await repository.record(channelID: "one", at: Date(timeIntervalSince1970: 1))
        try await repository.record(channelID: "two", at: Date(timeIntervalSince1970: 2))
        try await repository.record(channelID: "one", at: Date(timeIntervalSince1970: 3))

        let result = try await repository.load()

        #expect(result.map(\.channelID) == ["one", "two"])
        #expect(result.first?.watchedAt == Date(timeIntervalSince1970: 3))
        await repository.clear()
    }

    @Test
    func respectsMaximumHistorySize() async throws {
        let repository = makeRepository(maximumCount: 2)
        await repository.clear()

        try await repository.record(channelID: "one", at: .now)
        try await repository.record(channelID: "two", at: .now)
        try await repository.record(channelID: "three", at: .now)

        let result = try await repository.load()

        #expect(result.map(\.channelID) == ["three", "two"])
        await repository.clear()
    }

    private func makeRepository(
        maximumCount: Int = 20
    ) -> UserDefaultsRecentlyWatchedRepository {
        UserDefaultsRecentlyWatchedRepository(
            suiteName: "WorldTVTests.\(UUID().uuidString)",
            maximumCount: maximumCount
        )
    }
}
