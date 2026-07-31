import Foundation

protocol IPTVOrgCatalogProviding: Sendable {
    func fetchCatalog() async throws -> IPTVOrgCatalogPayload
}

struct IPTVOrgAPIClient: IPTVOrgCatalogProviding {
    private let httpClient: any HTTPClient
    private let decoder: JSONDecoder

    init(httpClient: any HTTPClient, decoder: JSONDecoder = JSONDecoder()) {
        self.httpClient = httpClient
        self.decoder = decoder
    }

    func fetchCatalog() async throws -> IPTVOrgCatalogPayload {
        async let channels: [IPTVOrgChannelDTO] = fetch(.channels)
        async let streams: [IPTVOrgStreamDTO] = fetch(.streams)
        async let logos: [IPTVOrgLogoDTO] = fetch(.logos)
        async let countries: [IPTVOrgCountryDTO] = fetch(.countries)
        async let categories: [IPTVOrgCategoryDTO] = fetch(.categories)
        async let blocklist: [IPTVOrgBlocklistDTO] = fetch(.blocklist)
        async let feeds: [IPTVOrgFeedDTO] = fetch(.feeds)
        async let languages: [IPTVOrgLanguageDTO] = fetch(.languages)

        return try await IPTVOrgCatalogPayload(
            channels: channels,
            streams: streams,
            logos: logos,
            countries: countries,
            categories: categories,
            blocklist: blocklist,
            feeds: feeds,
            languages: languages
        )
    }

    private func fetch<Value: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> Value {
        guard let url = endpoint.url else {
            throw HTTPError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("WorldTV/1.0", forHTTPHeaderField: "User-Agent")

        let data = try await httpClient.data(for: request)
        return try decoder.decode(Value.self, from: data)
    }
}
