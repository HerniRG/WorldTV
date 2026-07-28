import Foundation
import OSLog

actor DefaultCatalogRepository: ChannelRepository, CountryRepository {
    private let apiClient: IPTVOrgAPIClient
    private let mapper: IPTVOrgMapper
    private let logger = Logger(subsystem: "hrgapps.WorldTV", category: "catalog")
    private var catalog: Catalog?

    init(apiClient: IPTVOrgAPIClient, mapper: IPTVOrgMapper = IPTVOrgMapper()) {
        self.apiClient = apiClient
        self.mapper = mapper
    }

    func loadCatalog() async throws -> Catalog {
        if let catalog {
            return catalog
        }

        do {
            let payload = try await apiClient.fetchCatalog()
            let mappedCatalog = mapper.map(payload)
            catalog = mappedCatalog
            logger.info(
                "Catalog loaded with \(mappedCatalog.channels.count, privacy: .public) channels"
            )
            return mappedCatalog
        } catch {
            logger.error("Catalog loading failed: \(String(describing: error), privacy: .private)")
            throw error
        }
    }

    func loadCountries() async throws -> [Country] {
        try await loadCatalog().countries
    }
}
