import Foundation
import Testing
@testable import WorldTV

struct CatalogIndexTests {
    private let catalog = IPTVOrgMapper().map(IPTVOrgFixtures.catalogPayload)

    @Test
    func indexesChannelsByIdentifierAndCountry() {
        #expect(catalog.index.channelsByID["News.es"]?.name == "News")
        #expect(catalog.index.channels(countryCode: "ES").map(\.id) == ["News.es"])
        #expect(catalog.index.channels(countryCode: "US").isEmpty)
    }

    @Test
    func selectsPreferredLogo() {
        #expect(
            catalog.index.preferredLogoByChannelID["News.es"]?.url.absoluteString
                == "https://example.com/news.png"
        )
    }

    @Test
    func indexesFeedsLanguagesAndBroadcasters() {
        #expect(
            catalog.index.feedsByChannelID["News.es"]?.map(\.id)
                == ["main", "intl"]
        )
        #expect(
            catalog.index.languageCodesByChannelID["News.es"]
                == ["eng", "spa"]
        )
        #expect(
            catalog.index.channelsByBroadcaster["News Network"]?.map(\.id)
                == ["News.es"]
        )
    }

    @Test
    func fallbackLanguagesUseCountryCodes() {
        #expect(catalog.languages.map(\.code) == ["eng", "spa"])
        #expect(catalog.languages.first(where: { $0.code == "spa" })?.name == "Spanish")
    }
}
