import Testing
@testable import WorldTV

struct CatalogUseCaseTests {
    private let catalog = IPTVOrgMapper().map(IPTVOrgFixtures.catalogPayload)

    @Test
    func homeContentContainsFeaturedChannelsAndCountries() async throws {
        let useCase = LoadHomeContentUseCase(
            repository: StubChannelRepository(catalog: catalog)
        )

        let content = try await useCase.execute()

        #expect(content.summary.channelCount == 1)
        #expect(content.featuredChannels.map(\.id) == ["News.es"])
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

private struct StubChannelRepository: ChannelRepository {
    let catalog: Catalog

    func loadCatalog(forceRefresh: Bool) async throws -> Catalog {
        catalog
    }
}
