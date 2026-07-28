import Foundation

protocol ChannelRepository: Sendable {
    func loadCatalog() async throws -> Catalog
}

protocol CountryRepository: Sendable {
    func loadCountries() async throws -> [Country]
}
