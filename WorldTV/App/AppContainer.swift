import Foundation

struct AppContainer {
    let loadHomeContent: LoadHomeContentUseCase
    let loadCountries: LoadCountriesUseCase
    let loadChannelsByCountry: LoadChannelsByCountryUseCase
    let imageLoader: any ImageLoading

    static func live() -> AppContainer {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 128 * 1_024 * 1_024
        )

        let httpClient = URLSessionHTTPClient(session: URLSession(configuration: configuration))
        let apiClient = IPTVOrgAPIClient(httpClient: httpClient)
        let imageLoader = URLSessionImageLoader(session: URLSession(configuration: configuration))
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

        return AppContainer(
            loadHomeContent: LoadHomeContentUseCase(repository: repository),
            loadCountries: LoadCountriesUseCase(repository: repository),
            loadChannelsByCountry: LoadChannelsByCountryUseCase(repository: repository),
            imageLoader: imageLoader
        )
    }
}
