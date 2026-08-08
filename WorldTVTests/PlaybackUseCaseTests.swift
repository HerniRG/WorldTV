import Foundation
import Testing
@testable import WorldTV

struct PlaybackUseCaseTests {
    @Test
    func prefersHLSAndThenHighestQuality() async throws {
        let catalog = makeCatalog(
            streams: [
                stream("https://example.com/high.mp4", quality: "2160p"),
                stream("https://example.com/low.m3u8", quality: "720p"),
                stream("https://example.com/high.m3u8", quality: "1080p")
            ]
        )
        let useCase = ResolvePlayableStreamUseCase(
            repository: PlaybackStubChannelRepository(catalog: catalog)
        )

        let context = try await useCase.execute(channelID: "news")

        #expect(context.sources.map(\.url.lastPathComponent) == [
            "high.m3u8",
            "low.m3u8",
            "high.mp4"
        ])
    }

    @Test
    func limitsFallbackSources() async throws {
        let catalog = makeCatalog(
            streams: (0..<12).map {
                stream("https://example.com/\($0).m3u8", quality: "720p")
            }
        )
        let useCase = ResolvePlayableStreamUseCase(
            repository: PlaybackStubChannelRepository(catalog: catalog),
            maximumAttempts: 3
        )

        let context = try await useCase.execute(channelID: "news")

        #expect(context.sources.count == 3)
    }

    @Test
    func preferredQualityIsTriedBeforeHigherQuality() async throws {
        let catalog = makeCatalog(
            streams: [
                stream("https://example.com/uhd.m3u8", quality: "2160p"),
                stream("https://example.com/hd.m3u8", quality: "720p"),
                stream("https://example.com/fullhd.m3u8", quality: "1080p")
            ]
        )
        let useCase = ResolvePlayableStreamUseCase(
            repository: PlaybackStubChannelRepository(catalog: catalog)
        )

        let context = try await useCase.execute(
            channelID: "news",
            preferredQuality: 720
        )

        #expect(context.sources.first?.quality == "720p")
    }

    @Test
    func reportsChannelWithoutSources() async throws {
        let useCase = ResolvePlayableStreamUseCase(
            repository: PlaybackStubChannelRepository(catalog: makeCatalog(streams: []))
        )

        do {
            _ = try await useCase.execute(channelID: "news")
            Issue.record("Expected noSources")
        } catch let error as PlaybackError {
            #expect(error == .noSources)
        }
    }

    @Test
    func prefersStreamsFromSelectedFeed() async throws {
        let catalog = makeCatalog(
            streams: [
                stream("https://example.com/main.m3u8", quality: "1080p", feed: "main"),
                stream("https://example.com/intl.m3u8", quality: "720p", feed: "intl"),
                stream("https://example.com/unassigned.m3u8", quality: "1080p", feed: nil)
            ],
            feeds: [
                ChannelFeed(
                    id: "main",
                    channelID: "news",
                    name: "Main",
                    isMain: true,
                    languages: [],
                    broadcastArea: [],
                    timezones: [],
                    videoFormat: nil,
                    altNames: []
                ),
                ChannelFeed(
                    id: "intl",
                    channelID: "news",
                    name: "International",
                    isMain: false,
                    languages: [],
                    broadcastArea: [],
                    timezones: [],
                    videoFormat: nil,
                    altNames: []
                )
            ]
        )
        let useCase = ResolvePlayableStreamUseCase(
            repository: PlaybackStubChannelRepository(catalog: catalog)
        )

        let context = try await useCase.execute(channelID: "news", feedID: "intl")

        #expect(context.sources.map(\.url.lastPathComponent) == ["intl.m3u8"])
        #expect(context.feeds.map(\.id) == ["main", "intl"])
    }

    @Test
    func unknownFeedFallsBackToAllSources() async throws {
        let catalog = makeCatalog(
            streams: [
                stream("https://example.com/main.m3u8", quality: "1080p", feed: "main"),
                stream("https://example.com/other.m3u8", quality: "720p", feed: nil)
            ]
        )
        let useCase = ResolvePlayableStreamUseCase(
            repository: PlaybackStubChannelRepository(catalog: catalog)
        )

        let context = try await useCase.execute(channelID: "news", feedID: "missing")

        #expect(context.sources.count == 2)
    }

    private func makeCatalog(streams: [ChannelStream], feeds: [ChannelFeed] = []) -> Catalog {
        Catalog(
            channels: [
                Channel(
                    id: "news",
                    name: "News",
                    alternativeNames: [],
                    countryCode: "ES",
                    categoryIDs: ["news"],
                    isNSFW: false,
                    network: nil,
                    owners: [],
                    launched: nil,
                    closed: nil,
                    replacedBy: nil,
                    website: nil
                )
            ],
            countries: [
                Country(code: "ES", name: "Spain", languageCodes: ["spa"], flag: "🇪🇸")
            ],
            categories: [ChannelCategory(id: "news", name: "News", description: "News and current affairs")],
            streamsByChannelID: ["news": streams],
            logosByChannelID: [:],
            feeds: feeds
        )
    }

    private func stream(_ value: String, quality: String, feed: String? = nil) -> ChannelStream {
        let url = URL(string: value)!
        return ChannelStream(
            id: url,
            channelID: "news",
            url: url,
            feed: feed,
            title: nil,
            quality: quality,
            label: nil,
            referrer: nil,
            userAgent: nil
        )
    }
}

struct PlaybackSessionTests {
    @Test
    func advancesToTheNextSourceAfterFailure() {
        var session = PlaybackSession(sources: makeSources(count: 2))

        #expect(session.start() == .prepareSource(0))
        #expect(session.handle(.started) == .none)
        #expect(session.handle(.sourceFailed) == .prepareSource(1))
        #expect(session.state == .preparing)
        #expect(session.currentSourceIndex == 1)
    }

    @Test
    func reportsAllSourcesFailedAfterLastAttempt() {
        var session = PlaybackSession(sources: makeSources(count: 2))

        _ = session.start()
        _ = session.handle(.sourceFailed)

        #expect(session.handle(.sourceFailed) == .failed(.allSourcesFailed))
        #expect(session.state == .failed(.allSourcesFailed))
    }

    @Test
    func tracksBufferingAndRecoveryWithoutChangingSource() {
        var session = PlaybackSession(sources: makeSources(count: 1))

        _ = session.start()
        #expect(session.handle(.started) == .none)
        #expect(session.state == .playing)
        #expect(session.handle(.waiting) == .none)
        #expect(session.state == .buffering)
        #expect(session.handle(.started) == .none)
        #expect(session.state == .playing)
        #expect(session.currentSourceIndex == 0)
    }

    @Test
    func retryStartsWithTheFirstSource() {
        var session = PlaybackSession(sources: makeSources(count: 2))

        _ = session.start()
        _ = session.handle(.sourceFailed)

        #expect(session.retry() == .prepareSource(0))
        #expect(session.currentSourceIndex == 0)
        #expect(session.state == .preparing)
    }

    private static func makeSources(count: Int) -> [PlaybackSource] {
        (0..<count).map { index in
            PlaybackSource(
                url: URL(string: "https://example.com/source-\(index).m3u8")!,
                quality: "720p",
                title: "Source \(index)",
                label: nil,
                referrer: nil,
                userAgent: nil,
                isHLS: true
            )
        }
    }
}

private struct PlaybackStubChannelRepository: ChannelRepository {
    let catalog: Catalog

    func loadCatalog(forceRefresh: Bool) async throws -> Catalog {
        catalog
    }
}
