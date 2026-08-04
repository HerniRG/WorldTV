import Foundation
import Testing
@testable import WorldTV

struct M3UPlaylistParserTests {
    @Test
    func parsesMetadataAndStreamIntoTheSharedCatalog() throws {
        let source = PlaylistSource(name: "Demo", url: URL(string: "https://example.com/demo.m3u")!)
        let playlist = """
        #EXTM3U
        #EXTINF:-1 tvg-id="news.es" tvg-country="ES" tvg-logo="https://example.com/news.png" group-title="News",News HD
        #EXTVLCOPT:http-referrer=https://example.com/
        https://example.com/live.m3u8
        """

        let catalog = try M3UPlaylistParser().parse(Data(playlist.utf8), source: source)

        #expect(catalog.channels.count == 1)
        #expect(catalog.channels[0].name == "News HD")
        #expect(catalog.channels[0].countryCode == "ES")
        #expect(catalog.categories.map(\.name) == ["News"])
        #expect(catalog.streamsByChannelID[catalog.channels[0].id]?.first?.url.absoluteString == "https://example.com/live.m3u8")
        #expect(catalog.streamsByChannelID[catalog.channels[0].id]?.first?.referrer == "https://example.com/")
        #expect(catalog.logosByChannelID[catalog.channels[0].id]?.count == 1)
    }

    @Test
    func infersCountryFromTheCommonTvgIDFormat() throws {
        let source = PlaylistSource(name: "Demo", url: URL(string: "https://example.com/demo.m3u")!)
        let playlist = """
        #EXTM3U
        #EXTINF:-1 tvg-id="Example.es@HD",Example
        https://example.com/live.m3u8
        """

        let catalog = try M3UPlaylistParser().parse(Data(playlist.utf8), source: source)

        #expect(catalog.channels.first?.countryCode == "ES")
    }

    @Test
    func groupsQualityVariantsIntoOneChannelWithMultipleStreams() throws {
        let source = PlaylistSource(name: "Demo", url: URL(string: "https://example.com/demo.m3u")!)
        let playlist = """
        #EXTM3U
        #EXTINF:-1 tvg-id="Example.es@SD",Example (720p)
        https://example.com/example-720.m3u8
        #EXTINF:-1 tvg-id="Example.es@HD",Example (1080p)
        https://example.com/example-1080.m3u8
        """

        let catalog = try M3UPlaylistParser().parse(Data(playlist.utf8), source: source)
        let streams = catalog.streamsByChannelID[catalog.channels[0].id] ?? []

        #expect(catalog.channels.count == 1)
        #expect(streams.count == 2)
        #expect(streams.map(\.quality).contains("1080p"))
    }

    @Test
    func usesAnUnclassifiedBucketWhenCountryMetadataIsMissing() throws {
        let source = PlaylistSource(name: "Demo", url: URL(string: "https://example.com/demo.m3u")!)
        let playlist = """
        #EXTM3U
        #EXTINF:-1 group-title="Documentary",Global channel
        https://example.com/global.m3u8
        """

        let catalog = try M3UPlaylistParser().parse(Data(playlist.utf8), source: source)

        #expect(catalog.channels.first?.countryCode == "ZZ")
        #expect(catalog.countries.first?.name == "Unclassified")
        #expect(catalog.categories.map(\.name) == ["Documentary"])
    }

    @Test
    func ignoresEntriesWithoutHTTPStreams() throws {
        let source = PlaylistSource(name: "Demo", url: URL(string: "https://example.com/demo.m3u")!)
        let playlist = """
        #EXTM3U
        #EXTINF:-1,Invalid
        rtmp://example.com/live
        #EXTINF:-1,Valid
        https://example.com/live.m3u8
        """

        let catalog = try M3UPlaylistParser().parse(Data(playlist.utf8), source: source)

        #expect(catalog.channels.count == 1)
        #expect(catalog.channels[0].name == "Valid")
    }

    @Test
    func rejectsPlaylistWithoutPlayableEntries() {
        let source = PlaylistSource(name: "Demo", url: URL(string: "https://example.com/demo.m3u")!)
        let playlist = "#EXTM3U\n#EXTINF:-1,Invalid\nnot-a-url\n"

        #expect(throws: PlaylistSourceError.noPlayableEntries) {
            try M3UPlaylistParser().parse(Data(playlist.utf8), source: source)
        }
    }

    @Test
    func acceptsSimpleURLListsAndRelativeURLs() throws {
        let source = PlaylistSource(name: "Demo", url: URL(string: "https://example.com/playlists/demo.m3u")!)
        let playlist = """
        #EXTM3U
        streams/news.m3u8
        https://example.com/sports.m3u8|User-Agent=WorldTV%2F1.0&Referer=https%3A%2F%2Fexample.com
        """

        let catalog = try M3UPlaylistParser().parse(Data(playlist.utf8), source: source)

        #expect(catalog.channels.count == 2)
        #expect(catalog.streamsByChannelID.values.flatMap { $0 }.first?.url.absoluteString == "https://example.com/playlists/streams/news.m3u8")
        #expect(catalog.streamsByChannelID.values.flatMap { $0 }.last?.userAgent == "WorldTV/1.0")
        #expect(catalog.streamsByChannelID.values.flatMap { $0 }.last?.referrer == "https://example.com")
    }

    @Test
    func rejectsAnHLSMediaManifestAsAChannelList() {
        let source = PlaylistSource(name: "Demo", url: URL(string: "https://example.com/live.m3u8")!)
        let manifest = """
        #EXTM3U
        #EXT-X-TARGETDURATION:6
        #EXTINF:6,
        segment-1.ts
        """

        #expect(throws: PlaylistSourceError.noPlayableEntries) {
            try M3UPlaylistParser().parse(Data(manifest.utf8), source: source)
        }
    }
}
