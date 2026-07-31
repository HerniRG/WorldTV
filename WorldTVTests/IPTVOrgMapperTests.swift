import Foundation
import Testing
@testable import WorldTV

struct IPTVOrgMapperTests {
    private let catalog = IPTVOrgMapper().map(IPTVOrgFixtures.catalogPayload)

    @Test
    func filtersNSFWBlockedAndClosedChannels() {
        #expect(catalog.channels.map(\.id) == ["News.es"])
    }

    @Test
    func associatesHTTPAndHTTPSStreamsWithKnownChannels() throws {
        let streams = try #require(catalog.streamsByChannelID["News.es"])

        #expect(streams.count == 2)
        #expect(
            streams.map(\.url.absoluteString).sorted()
                == [
                    "http://example.com/insecure.m3u8",
                    "https://example.com/live.m3u8"
                ]
        )
        #expect(catalog.streamsByChannelID["Missing.es"] == nil)
    }

    @Test
    func associatesOnlySecureLogosWithKnownChannels() throws {
        let logos = try #require(catalog.logosByChannelID["News.es"])

        #expect(logos.count == 1)
        #expect(logos.first?.url.absoluteString == "https://example.com/news.png")
        #expect(logos.first?.isInUse == true)
        #expect(catalog.logosByChannelID["Missing.es"] == nil)
    }

    @Test
    func producesCatalogSummary() {
        #expect(
            catalog.summary == CatalogSummary(
                countryCount: 1,
                channelCount: 1,
                playableChannelCount: 1
            )
        )
    }
}
