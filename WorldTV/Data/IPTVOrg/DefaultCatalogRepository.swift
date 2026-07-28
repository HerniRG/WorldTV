import Foundation
import OSLog

actor DefaultCatalogRepository: ChannelRepository, CountryRepository {
    private let apiClient: any IPTVOrgCatalogProviding
    private let mapper: IPTVOrgMapper
    private let cache: any CatalogCaching
    private let now: @Sendable () -> Date
    private let cacheMaxAge: TimeInterval
    private let logger = Logger(subsystem: "hrgapps.WorldTV", category: "catalog")
    private var catalog: Catalog?

    init(
        apiClient: any IPTVOrgCatalogProviding,
        mapper: IPTVOrgMapper = IPTVOrgMapper(),
        cache: any CatalogCaching,
        cacheMaxAge: TimeInterval = 24 * 60 * 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.apiClient = apiClient
        self.mapper = mapper
        self.cache = cache
        self.cacheMaxAge = cacheMaxAge
        self.now = now
    }

    func loadCatalog(forceRefresh: Bool) async throws -> Catalog {
        if let catalog, !forceRefresh {
            return catalog
        }

        let cachedSnapshot: CachedCatalogSnapshot?
        do {
            cachedSnapshot = try await cache.load()
        } catch {
            cachedSnapshot = nil
            logger.warning("Cached catalog could not be read")
        }
        if
            !forceRefresh,
            let cachedSnapshot,
            cachedSnapshot.isFresh(at: now(), maxAge: cacheMaxAge)
        {
            let mappedCatalog = mapper.map(cachedSnapshot.payload)
            catalog = mappedCatalog
            logger.info("Fresh cached catalog loaded")
            return mappedCatalog
        }

        do {
            let payload = try await apiClient.fetchCatalog()
            let mappedCatalog = mapper.map(payload)
            catalog = mappedCatalog
            do {
                try await cache.save(CachedCatalogSnapshot(savedAt: now(), payload: payload))
            } catch {
                logger.warning("Catalog loaded but could not be cached")
            }
            logger.info(
                "Catalog loaded with \(mappedCatalog.channels.count, privacy: .public) channels"
            )
            return mappedCatalog
        } catch {
            if let cachedSnapshot {
                let mappedCatalog = mapper.map(cachedSnapshot.payload)
                catalog = mappedCatalog
                logger.warning("Network failed; stale cached catalog loaded")
                return mappedCatalog
            }
            logger.error("Catalog loading failed: \(String(describing: error), privacy: .private)")
            throw error
        }
    }

    func loadCountries() async throws -> [Country] {
        try await loadCatalog(forceRefresh: false).countries
    }
}
