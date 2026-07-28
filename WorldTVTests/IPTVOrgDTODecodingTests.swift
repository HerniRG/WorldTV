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
}
