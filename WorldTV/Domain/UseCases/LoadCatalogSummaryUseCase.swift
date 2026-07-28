import Foundation

struct LoadCatalogSummaryUseCase: Sendable {
    private let repository: any ChannelRepository

    init(repository: any ChannelRepository) {
        self.repository = repository
    }

    func execute() async throws -> CatalogSummary {
        try await repository.loadCatalog().summary
    }
}
