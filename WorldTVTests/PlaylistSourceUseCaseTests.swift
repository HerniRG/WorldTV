import Foundation
import Testing
@testable import WorldTV

struct PlaylistSourceUseCaseTests {
    @Test
    func startsEmptyAndPersistsSourcesThroughTheUseCases() async throws {
        let store = InMemoryPlaylistSourceStore()
        let invalidation = InvalidationSpy()
        let load = LoadPlaylistSourcesUseCase(store: store)
        let add = AddPlaylistSourceUseCase(store: store) {
            await invalidation.record()
        }
        let remove = RemovePlaylistSourceUseCase(store: store) {
            await invalidation.record()
        }

        #expect(try await load.execute().isEmpty)
        let source = try await add.execute(name: "Demo", urlString: "https://example.com/demo.m3u")
        #expect(try await load.execute() == [source])
        #expect(await invalidation.count == 1)

        try await remove.execute(id: source.id)
        #expect(try await load.execute().isEmpty)
        #expect(await invalidation.count == 2)
    }

    @Test
    func rejectsNonHTTPPlaylistURLs() async {
        let store = InMemoryPlaylistSourceStore()
        let add = AddPlaylistSourceUseCase(store: store) {}

        do {
            _ = try await add.execute(name: "Local", urlString: "file:///tmp/demo.m3u")
            Issue.record("Expected unsupportedURLScheme")
        } catch let error as PlaylistSourceError {
            #expect(error == .unsupportedURLScheme)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private actor InMemoryPlaylistSourceStore: PlaylistSourceStore {
    private var sources: [PlaylistSource] = []

    func load() -> [PlaylistSource] { sources }
    func add(_ source: PlaylistSource) { sources.append(source) }
    func remove(id: UUID) { sources.removeAll { $0.id == id } }
}

private actor InvalidationSpy {
    private(set) var count = 0

    func record() { count += 1 }
}
