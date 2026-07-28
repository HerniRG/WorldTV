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

    private func makeCatalog(streams: [ChannelStream]) -> Catalog {
        Catalog(
            channels: [
                Channel(
                    id: "news",
                    name: "News",
                    alternativeNames: [],
                    countryCode: "ES",
                    categoryIDs: ["news"],
                    isNSFW: false
                )
            ],
            countries: [
                Country(code: "ES", name: "Spain", languageCodes: ["spa"], flag: "🇪🇸")
            ],
            categories: [ChannelCategory(id: "news", name: "News")],
            streamsByChannelID: ["news": streams],
            logosByChannelID: [:]
        )
    }

    private func stream(_ value: String, quality: String) -> ChannelStream {
        let url = URL(string: value)!
        return ChannelStream(
            id: url,
            channelID: "news",
            url: url,
            feed: nil,
            title: nil,
            quality: quality,
            label: nil,
            referrer: nil,
            userAgent: nil
        )
    }
}

private struct PlaybackStubChannelRepository: ChannelRepository {
    let catalog: Catalog

    func loadCatalog(forceRefresh: Bool) async throws -> Catalog {
        catalog
    }
}
