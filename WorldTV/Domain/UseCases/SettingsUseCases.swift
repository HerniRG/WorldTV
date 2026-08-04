import Foundation

struct RefreshCatalogUseCase: Sendable {
    private let repository: any ChannelRepository
    private let metadataStore: any CatalogMetadataStore

    init(repository: any ChannelRepository, metadataStore: any CatalogMetadataStore) {
        self.repository = repository
        self.metadataStore = metadataStore
    }

    func execute() async throws -> CatalogSummary {
        let summary = try await repository.loadCatalog(forceRefresh: true).summary
        try await metadataStore.save(date: .now)
        return summary
    }
}

struct ClearRecentlyWatchedUseCase: Sendable {
    private let repository: any RecentlyWatchedRepository

    init(repository: any RecentlyWatchedRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.clear()
    }
}

struct ClearCatalogCacheUseCase: Sendable {
    private let cache: any CatalogMetadataStore
    private let invalidate: @Sendable () async -> Void

    init(cache: any CatalogMetadataStore, invalidate: @escaping @Sendable () async -> Void = {}) {
        self.cache = cache
        self.invalidate = invalidate
    }

    func execute() async throws {
        try await cache.clear()
        await invalidate()
    }
}

struct LoadCatalogCacheDateUseCase: Sendable {
    private let cache: any CatalogMetadataStore

    init(cache: any CatalogMetadataStore) {
        self.cache = cache
    }

    func execute() async throws -> Date? {
        try await cache.load()
    }
}
