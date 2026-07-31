import Foundation

@MainActor
struct AppContainer {
    let loadHomeContent: LoadHomeContentUseCase
    let loadCountries: LoadCountriesUseCase
    let loadChannelsByCountry: LoadChannelsByCountryUseCase
    let loadCategories: LoadCategoriesUseCase
    let loadChannelsByCategory: LoadChannelsByCategoryUseCase
    let loadChannelDetail: LoadChannelDetailUseCase
    let loadChannelsByBroadcaster: LoadChannelsByBroadcasterUseCase
    let resolvePlaybackSources: ResolvePlayableStreamUseCase
    let recordRecentlyWatched: RecordRecentlyWatchedUseCase
    let loadFavoriteChannels: LoadFavoriteChannelsUseCase
    let searchChannels: SearchChannelsUseCase
    let favoritesStore: FavoritesStore
    let refreshCatalog: RefreshCatalogUseCase
    let clearRecentlyWatched: ClearRecentlyWatchedUseCase
    let clearCatalogCache: ClearCatalogCacheUseCase
    let loadCatalogCacheDate: LoadCatalogCacheDateUseCase

    static func live() -> AppContainer {
        let urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 128 * 1_024 * 1_024
        )
        URLCache.shared = urlCache

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = urlCache

        let httpClient = URLSessionHTTPClient(session: URLSession(configuration: configuration))
        let apiClient = IPTVOrgAPIClient(httpClient: httpClient)
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let cache = FileCatalogCache(
            fileURL: baseDirectory
                .appendingPathComponent("WorldTV", isDirectory: true)
                .appendingPathComponent("catalog.json")
        )
        let repository = DefaultCatalogRepository(apiClient: apiClient, cache: cache)
        let recentlyWatchedRepository = UserDefaultsRecentlyWatchedRepository()
        let favoritesRepository = UserDefaultsFavoritesRepository()
        let favoritesStore = FavoritesStore(
            loadFavorites: LoadFavoriteChannelIDsUseCase(repository: favoritesRepository),
            toggleFavorite: ToggleFavoriteUseCase(repository: favoritesRepository),
            clearFavorites: ClearFavoritesUseCase(repository: favoritesRepository)
        )

        return AppContainer(
            loadHomeContent: LoadHomeContentUseCase(
                repository: repository,
                recentlyWatchedRepository: recentlyWatchedRepository,
                favoritesRepository: favoritesRepository
            ),
            loadCountries: LoadCountriesUseCase(repository: repository),
            loadChannelsByCountry: LoadChannelsByCountryUseCase(repository: repository),
            loadCategories: LoadCategoriesUseCase(repository: repository),
            loadChannelsByCategory: LoadChannelsByCategoryUseCase(repository: repository),
            loadChannelDetail: LoadChannelDetailUseCase(repository: repository),
            loadChannelsByBroadcaster: LoadChannelsByBroadcasterUseCase(repository: repository),
            resolvePlaybackSources: ResolvePlayableStreamUseCase(repository: repository),
            recordRecentlyWatched: RecordRecentlyWatchedUseCase(
                repository: recentlyWatchedRepository
            ),
            loadFavoriteChannels: LoadFavoriteChannelsUseCase(
                channelRepository: repository,
                favoritesRepository: favoritesRepository
            ),
            searchChannels: SearchChannelsUseCase(
                channelRepository: repository,
                favoritesRepository: favoritesRepository
            ),
            favoritesStore: favoritesStore,
            refreshCatalog: RefreshCatalogUseCase(repository: repository),
            clearRecentlyWatched: ClearRecentlyWatchedUseCase(
                repository: recentlyWatchedRepository
            ),
            clearCatalogCache: ClearCatalogCacheUseCase(cache: cache),
            loadCatalogCacheDate: LoadCatalogCacheDateUseCase(cache: cache)
        )
    }
}
