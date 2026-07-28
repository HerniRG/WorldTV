import Foundation

struct RefreshCatalogUseCase: Sendable {
    private let repository: any ChannelRepository

    init(repository: any ChannelRepository) {
        self.repository = repository
    }

    func execute() async throws -> CatalogSummary {
        try await repository.loadCatalog(forceRefresh: true).summary
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
    private let cache: any CatalogCaching

    init(cache: any CatalogCaching) {
        self.cache = cache
    }

    func execute() async throws {
        try await cache.clear()
    }
}

struct LoadCatalogCacheDateUseCase: Sendable {
    private let cache: any CatalogCaching

    init(cache: any CatalogCaching) {
        self.cache = cache
    }

    func execute() async throws -> Date? {
        try await cache.load()?.savedAt
    }
}
