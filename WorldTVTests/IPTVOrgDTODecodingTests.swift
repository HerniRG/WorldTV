import Foundation
import Testing
@testable import WorldTV

struct IPTVOrgDTODecodingTests {
    private let decoder = JSONDecoder()

    @Test
    func decodesChannelFields() throws {
        let channels = try decoder.decode(
            [IPTVOrgChannelDTO].self,
            from: IPTVOrgFixtures.channelsJSON
        )

        let channel = try #require(channels.first)
        #expect(channel.id == "News.es")
        #expect(channel.alternativeNames == ["Noticias"])
        #expect(channel.country == "ES")
        #expect(channel.categories == ["news"])
        #expect(channel.isNSFW == false)
        #expect(channel.closed == nil)
    }

    @Test
    func decodesStreamFields() throws {
        let streams = try decoder.decode(
            [IPTVOrgStreamDTO].self,
            from: IPTVOrgFixtures.streamsJSON
        )

        let stream = try #require(streams.first)
        #expect(stream.channel == "News.es")
        #expect(stream.url == "https://example.com/live.m3u8")
        #expect(stream.quality == "1080p")
        #expect(stream.title == "News HD")
        #expect(stream.referrer == "https://example.com/")
    }

    @Test
    func decodesFeedAndLanguageFields() throws {
        let feeds = try decoder.decode(
            [IPTVOrgFeedDTO].self,
            from: Data(
                #"""
                [
                  {
                    "channel": "News.es",
                    "id": "main",
                    "name": "Main",
                    "is_main": true,
                    "languages": ["spa"]
                  }
                ]
                """#.utf8
            )
        )

        let feed = try #require(feeds.first)
        #expect(feed.channel == "News.es")
        #expect(feed.id == "main")
        #expect(feed.name == "Main")
        #expect(feed.isMain == true)
        #expect(feed.languages == ["spa"])

        let languages = try decoder.decode(
            [IPTVOrgLanguageDTO].self,
            from: Data(
                #"""
                [
                  { "name": "Spanish", "code": "spa" }
                ]
                """#.utf8
            )
        )
        #expect(languages.first?.code == "spa")
        #expect(languages.first?.name == "Spanish")
    }

    @Test
    func decodesNetworkOwnersAndLogoTags() throws {
        let channels = try decoder.decode(
            [IPTVOrgChannelDTO].self,
            from: Data(
                #"""
                [
                  {
                    "id": "News.es",
                    "name": "News",
                    "alt_names": [],
                    "country": "ES",
                    "categories": ["news"],
                    "is_nsfw": false,
                    "closed": null,
                    "network": "News Network",
                    "owners": ["Owner Corp"]
                  }
                ]
                """#.utf8
            )
        )
        let channel = try #require(channels.first)
        #expect(channel.network == "News Network")
        #expect(channel.owners == ["Owner Corp"])

        let logos = try decoder.decode(
            [IPTVOrgLogoDTO].self,
            from: Data(
                #"""
                [
                  {
                    "channel": "News.es",
                    "url": "https://example.com/news.png",
                    "in_use": true,
                    "tags": ["horizontal"]
                  }
                ]
                """#.utf8
            )
        )
        #expect(logos.first?.tags == ["horizontal"])
    }
}
