import Foundation
import Testing
@testable import WorldTV

struct FavoritesRepositoryTests {
    @Test
    func togglePreservesStableOrderAndRemovesExistingFavorite() async {
        let repository = UserDefaultsFavoritesRepository(
            suiteName: "WorldTVTests.Favorites.\(UUID().uuidString)"
        )
        await repository.clear()

        #expect(await repository.toggle(channelID: "one"))
        #expect(await repository.toggle(channelID: "two"))
        #expect(await repository.load() == ["one", "two"])
        #expect(await !repository.toggle(channelID: "one"))
        #expect(await repository.load() == ["two"])

        await repository.clear()
    }
}
