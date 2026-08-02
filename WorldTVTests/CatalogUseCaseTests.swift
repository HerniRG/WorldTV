import Foundation
import Testing
@testable import WorldTV

struct CatalogUseCaseTests {
    private let catalog = IPTVOrgMapper().map(IPTVOrgFixtures.catalogPayload)

    @Test
    func homeContentContainsFeaturedChannelsAndCountries() async throws {
        let useCase = LoadHomeContentUseCase(
            repository: StubChannelRepository(catalog: catalog),
            recentlyWatchedRepository: StubRecentlyWatchedRepository(
                items: [RecentlyWatchedChannel(channelID: "News.es", watchedAt: .now)]
            ),
            favoritesRepository: StubFavoritesRepository(items: ["News.es"])
        )

        let content = try await useCase.execute()

        #expect(content.summary.channelCount == 1)
        #expect(content.featuredChannels.map(\.id) == ["News.es"])
        #expect(content.favoriteChannels.map(\.id) == ["News.es"])
        #expect(content.favoriteChannels.first?.logos.map(\.url.absoluteString) == [
            "https://example.com/news.png"
        ])
        #expect(content.recentlyWatched.map(\.id) == ["News.es"])
        #expect(content.popularCountries.map(\.id) == ["ES"])
    }

    @Test
    func loadsChannelsForCountry() async throws {
        let useCase = LoadChannelsByCountryUseCase(
            repository: StubChannelRepository(catalog: catalog)
        )

        let result = try #require(try await useCase.execute(countryCode: "ES"))

        #expect(result.country.code == "ES")
        #expect(result.channels.map(\.id) == ["News.es"])
        #expect(result.channels.first?.isAvailable == true)
    }
}

private struct StubFavoritesRepository: FavoritesRepository {
    let items: [String]

    func load() async throws -> [String] {
        items
    }

    func toggle(channelID: String) async throws -> Bool {
        !items.contains(channelID)
    }

    func clear() async throws {}
}

private struct StubRecentlyWatchedRepository: RecentlyWatchedRepository {
    let items: [RecentlyWatchedChannel]

    func load() async throws -> [RecentlyWatchedChannel] {
        items
    }

    func record(channelID: String, at date: Date) async throws {}

    func clear() async throws {}
}

private struct StubChannelRepository: ChannelRepository {
    let catalog: Catalog

    func loadCatalog(forceRefresh: Bool) async throws -> Catalog {
        catalog
    }
}
