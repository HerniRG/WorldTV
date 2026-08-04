import Foundation

actor PlaylistCatalogRepository: ChannelRepository {
    private let sourceStore: any PlaylistSourceStore
    private let httpClient: any HTTPClient
    private let parser: M3UPlaylistParser
    private var catalog: Catalog?

    init(sourceStore: any PlaylistSourceStore, httpClient: any HTTPClient, parser: M3UPlaylistParser = M3UPlaylistParser()) { self.sourceStore = sourceStore; self.httpClient = httpClient; self.parser = parser }

    func loadCatalog(forceRefresh: Bool) async throws -> Catalog {
        if let catalog, !forceRefresh { return catalog }
        let sources = try await sourceStore.load()
        guard !sources.isEmpty else { let empty = emptyCatalog(); catalog = empty; return empty }
        var catalogs: [Catalog] = []
        for source in sources {
            do {
                var request = URLRequest(url: source.url)
                request.setValue("application/vnd.apple.mpegurl, audio/mpegurl, text/plain, */*", forHTTPHeaderField: "Accept")
                request.setValue("WorldTV/1.0", forHTTPHeaderField: "User-Agent")
                catalogs.append(try parser.parse(try await httpClient.data(for: request), source: source))
            } catch { continue }
        }
        guard !catalogs.isEmpty else { throw PlaylistSourceError.noPlayableEntries }
        let merged = merge(catalogs); catalog = merged; return merged
    }

    func invalidate() { catalog = nil }

    private func merge(_ catalogs: [Catalog]) -> Catalog {
        let channels = catalogs.flatMap(\.channels)
        let countries = catalogs
            .flatMap(\.countries)
            .reduce(into: [String: Country]()) { result, country in
                result[country.code] = result[country.code] ?? country
            }
            .values
            .sorted { $0.name < $1.name }
        let categories = catalogs
            .flatMap(\.categories)
            .reduce(into: [String: ChannelCategory]()) { result, category in
                result[category.id] = result[category.id] ?? category
            }
            .values
            .sorted { $0.name < $1.name }
        let streams = catalogs.reduce(into: [String: [ChannelStream]]()) { result, catalog in for (id, values) in catalog.streamsByChannelID { result[id, default: []].append(contentsOf: values) } }
        let logos = catalogs.reduce(into: [String: [ChannelLogo]]()) { result, catalog in for (id, values) in catalog.logosByChannelID { result[id, default: []].append(contentsOf: values) } }
        return Catalog(channels: channels, countries: Array(countries), categories: Array(categories), streamsByChannelID: streams, logosByChannelID: logos)
    }

    private func emptyCatalog() -> Catalog { Catalog(channels: [], countries: [], categories: [], streamsByChannelID: [:], logosByChannelID: [:]) }
}
