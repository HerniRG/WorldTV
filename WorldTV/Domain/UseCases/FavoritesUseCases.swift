import Foundation

struct LoadFavoriteChannelIDsUseCase: Sendable {
    private let repository: any FavoritesRepository

    init(repository: any FavoritesRepository) {
        self.repository = repository
    }

    func execute() async throws -> [String] {
        try await repository.load()
    }
}

struct ToggleFavoriteUseCase: Sendable {
    private let repository: any FavoritesRepository

    init(repository: any FavoritesRepository) {
        self.repository = repository
    }

    func execute(channelID: String) async throws -> Bool {
        try await repository.toggle(channelID: channelID)
    }
}

struct ClearFavoritesUseCase: Sendable {
    private let repository: any FavoritesRepository

    init(repository: any FavoritesRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.clear()
    }
}

struct LoadFavoriteChannelsUseCase: Sendable {
    private let channelRepository: any ChannelRepository
    private let favoritesRepository: any FavoritesRepository

    init(
        channelRepository: any ChannelRepository,
        favoritesRepository: any FavoritesRepository
    ) {
        self.channelRepository = channelRepository
        self.favoritesRepository = favoritesRepository
    }

    func execute() async throws -> [ChannelCatalogItem] {
        async let catalog = channelRepository.loadCatalog()
        async let identifiers = favoritesRepository.load()
        let (loadedCatalog, loadedIdentifiers) = try await (catalog, identifiers)
        return loadedIdentifiers.compactMap { identifier in
            loadedCatalog.index.channelsByID[identifier]
        }
        .map { makeChannelCatalogItem($0, catalog: loadedCatalog) }
    }
}
