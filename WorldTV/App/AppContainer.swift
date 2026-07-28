import Foundation

struct AppContainer {
    let loadCatalogSummary: LoadCatalogSummaryUseCase

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
        let repository = DefaultCatalogRepository(apiClient: apiClient)

        return AppContainer(
            loadCatalogSummary: LoadCatalogSummaryUseCase(repository: repository)
        )
    }
}
