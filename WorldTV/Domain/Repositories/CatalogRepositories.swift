import Foundation

protocol ChannelRepository: Sendable {
    func loadCatalog(forceRefresh: Bool) async throws -> Catalog
}

protocol CountryRepository: Sendable {
    func loadCountries() async throws -> [Country]
}

extension ChannelRepository {
    func loadCatalog() async throws -> Catalog {
        try await loadCatalog(forceRefresh: false)
    }
}
