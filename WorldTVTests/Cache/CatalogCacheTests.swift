import Foundation
import Testing
@testable import WorldTV

struct CatalogCacheTests {
    @Test
    func snapshotFreshnessUsesMaximumAge() {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = CachedCatalogSnapshot(
            savedAt: savedAt,
            payload: IPTVOrgFixtures.catalogPayload
        )

        #expect(snapshot.isFresh(at: savedAt.addingTimeInterval(60), maxAge: 120))
        #expect(!snapshot.isFresh(at: savedAt.addingTimeInterval(121), maxAge: 120))
    }

    @Test
    func fileCacheRoundTripsAndClearsSnapshot() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("catalog.json")
        let cache = FileCatalogCache(fileURL: fileURL)
        let snapshot = CachedCatalogSnapshot(
            savedAt: Date(timeIntervalSince1970: 1_000),
            payload: IPTVOrgFixtures.catalogPayload
        )

        try await cache.save(snapshot)
        let loaded = try #require(try await cache.load())
        #expect(loaded.savedAt == snapshot.savedAt)
        #expect(loaded.payload.channels.count == snapshot.payload.channels.count)

        try await cache.clear()
        #expect(try await cache.load() == nil)
    }

    @Test
    func repositoryFallsBackToStaleCacheWhenNetworkFails() async throws {
        let snapshot = CachedCatalogSnapshot(
            savedAt: Date(timeIntervalSince1970: 1_000),
            payload: IPTVOrgFixtures.catalogPayload
        )
        let cache = MemoryCatalogCache(snapshot: snapshot)
        let repository = DefaultCatalogRepository(
            apiClient: FailingCatalogProvider(),
            cache: cache,
            cacheMaxAge: 60,
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        let catalog = try await repository.loadCatalog(forceRefresh: false)

        #expect(catalog.channels.map(\.id) == ["News.es"])
    }
}

private enum CatalogProviderError: Error {
    case unavailable
}

private struct FailingCatalogProvider: IPTVOrgCatalogProviding {
    func fetchCatalog() async throws -> IPTVOrgCatalogPayload {
        throw CatalogProviderError.unavailable
    }
}

private actor MemoryCatalogCache: CatalogCaching {
    private var snapshot: CachedCatalogSnapshot?

    init(snapshot: CachedCatalogSnapshot?) {
        self.snapshot = snapshot
    }

    func load() -> CachedCatalogSnapshot? {
        snapshot
    }

    func save(_ snapshot: CachedCatalogSnapshot) {
        self.snapshot = snapshot
    }

    func clear() {
        snapshot = nil
    }
}
