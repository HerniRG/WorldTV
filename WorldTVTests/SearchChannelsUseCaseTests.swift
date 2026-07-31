import Foundation
import Testing
@testable import WorldTV

struct SearchChannelsUseCaseTests {
    private let catalog = SearchFixture.catalog

    @Test
    func searchesAlternativeNamesCountriesCategoriesAndStreamTitles() async throws {
        let useCase = makeUseCase()

        #expect(try await identifiers(useCase, query: "Noticias") == ["news.es"])
        #expect(try await identifiers(useCase, query: "Spain") == ["news.es"])
        #expect(try await identifiers(useCase, query: "Sports") == ["sport.us"])
        #expect(try await identifiers(useCase, query: "Live Arena") == ["sport.us"])
    }

    @Test
    func appliesFavoritesQualityAvailabilityAndGeoFilters() async throws {
        let useCase = makeUseCase()
        let criteria = ChannelSearchCriteria(
            minimumQuality: 1080,
            favoritesOnly: true,
            availableOnly: true,
            includeGeoBlocked: false
        )

        let result = try await useCase.execute(criteria: criteria)

        #expect(result.channels.map(\.id) == ["sport.us"])
    }

    @Test
    func filtersChannelsByLanguage() async throws {
        let useCase = makeUseCase()

        let result = try await useCase.execute(
            criteria: ChannelSearchCriteria(languageCode: "spa")
        )

        #expect(result.channels.map(\.id) == ["news.es"])
        #expect(result.options.languages.map(\.code) == ["eng", "spa"])
    }

    private func makeUseCase() -> SearchChannelsUseCase {
        SearchChannelsUseCase(
            channelRepository: SearchStubChannelRepository(catalog: catalog),
            favoritesRepository: SearchStubFavoritesRepository(
                identifiers: ["news.es", "sport.us"]
            )
        )
    }

    private func identifiers(
        _ useCase: SearchChannelsUseCase,
        query: String
    ) async throws -> [String] {
        let result = try await useCase.execute(
            criteria: ChannelSearchCriteria(query: query)
        )
        return result.channels.map(\.id)
    }
}

private enum SearchFixture {
    static let catalog: Catalog = {
        let news = Channel(
            id: "news.es",
            name: "World News",
            alternativeNames: ["Noticias"],
            countryCode: "ES",
            categoryIDs: ["news"],
            isNSFW: false
        )
        let sport = Channel(
            id: "sport.us",
            name: "Arena",
            alternativeNames: [],
            countryCode: "US",
            categoryIDs: ["sports"],
            isNSFW: false
        )
        let offline = Channel(
            id: "offline.es",
            name: "Offline",
            alternativeNames: [],
            countryCode: "ES",
            categoryIDs: ["news"],
            isNSFW: false
        )
        return Catalog(
            channels: [news, sport, offline],
            countries: [
                Country(code: "ES", name: "Spain", languageCodes: [], flag: "🇪🇸"),
                Country(code: "US", name: "United States", languageCodes: [], flag: "🇺🇸")
            ],
            categories: [
                ChannelCategory(id: "news", name: "News"),
                ChannelCategory(id: "sports", name: "Sports")
            ],
            streamsByChannelID: [
                "news.es": [
                    stream(
                        channelID: "news.es",
                        path: "news.m3u8",
                        title: "News",
                        quality: "720p",
                        label: "Geo-blocked"
                    )
                ],
                "sport.us": [
                    stream(
                        channelID: "sport.us",
                        path: "sport.m3u8",
                        title: "Live Arena",
                        quality: "1080p",
                        label: nil
                    )
                ]
            ],
            logosByChannelID: [:],
            feeds: [
                ChannelFeed(
                    id: "news-feed",
                    channelID: "news.es",
                    name: "Main",
                    isMain: true,
                    languages: ["spa"]
                ),
                ChannelFeed(
                    id: "sport-feed",
                    channelID: "sport.us",
                    name: "Main",
                    isMain: true,
                    languages: ["eng"]
                )
            ],
            languages: [
                Language(code: "spa", name: "Spanish"),
                Language(code: "eng", name: "English")
            ]
        )
    }()

    private static func stream(
        channelID: String,
        path: String,
        title: String,
        quality: String,
        label: String?
    ) -> ChannelStream {
        let url = URL(string: "https://example.com/\(path)")
            ?? URL(fileURLWithPath: "/\(path)")
        return ChannelStream(
            id: url,
            channelID: channelID,
            url: url,
            feed: nil,
            title: title,
            quality: quality,
            label: label,
            referrer: nil,
            userAgent: nil
        )
    }
}

private struct SearchStubChannelRepository: ChannelRepository {
    let catalog: Catalog

    func loadCatalog(forceRefresh: Bool) async throws -> Catalog {
        catalog
    }
}

private struct SearchStubFavoritesRepository: FavoritesRepository {
    let identifiers: [String]

    func load() async throws -> [String] {
        identifiers
    }

    func toggle(channelID: String) async throws -> Bool {
        !identifiers.contains(channelID)
    }

    func clear() async throws {}
}
