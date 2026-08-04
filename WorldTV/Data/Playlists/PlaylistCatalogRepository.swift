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
        var canonicalIDByOriginalID: [String: String] = [:]
        var channelsByCanonicalID: [String: Channel] = [:]
        for channel in catalogs.flatMap(\.channels) {
            let canonicalID = canonicalChannelID(for: channel)
            canonicalIDByOriginalID[channel.id] = canonicalID
            if let existing = channelsByCanonicalID[canonicalID] {
                channelsByCanonicalID[canonicalID] = merge(existing, with: channel, id: canonicalID)
            } else {
                channelsByCanonicalID[canonicalID] = Channel(
                    id: canonicalID,
                    name: channel.name,
                    alternativeNames: channel.alternativeNames,
                    countryCode: channel.countryCode,
                    categoryIDs: channel.categoryIDs,
                    isNSFW: channel.isNSFW,
                    network: channel.network,
                    owners: channel.owners,
                    launched: channel.launched,
                    closed: channel.closed,
                    replacedBy: channel.replacedBy,
                    website: channel.website
                )
            }
        }
        let channels = Array(channelsByCanonicalID.values).sorted { $0.name < $1.name }
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
        let streams = catalogs.reduce(into: [String: [ChannelStream]]()) { result, catalog in
            for (id, values) in catalog.streamsByChannelID {
                guard let canonicalID = canonicalIDByOriginalID[id] else { continue }
                for stream in values where !result[canonicalID, default: []].contains(where: { $0.url == stream.url }) {
                    result[canonicalID, default: []].append(
                        ChannelStream(
                            id: stream.url,
                            channelID: canonicalID,
                            url: stream.url,
                            feed: stream.feed,
                            title: stream.title,
                            quality: stream.quality,
                            label: stream.label,
                            referrer: stream.referrer,
                            userAgent: stream.userAgent
                        )
                    )
                }
            }
        }
        let logos = catalogs.reduce(into: [String: [ChannelLogo]]()) { result, catalog in
            for (id, values) in catalog.logosByChannelID {
                guard let canonicalID = canonicalIDByOriginalID[id] else { continue }
                for logo in values where !result[canonicalID, default: []].contains(where: { $0.url == logo.url }) {
                    result[canonicalID, default: []].append(
                        ChannelLogo(
                            id: logo.url,
                            channelID: canonicalID,
                            url: logo.url,
                            feed: logo.feed,
                            width: logo.width,
                            height: logo.height,
                            format: logo.format,
                            isInUse: logo.isInUse,
                            tags: logo.tags
                        )
                    )
                }
            }
        }
        return Catalog(channels: channels, countries: Array(countries), categories: Array(categories), streamsByChannelID: streams, logosByChannelID: logos)
    }

    private func canonicalChannelID(for channel: Channel) -> String {
        let identifier = channel.id.split(separator: "|").last.map(String.init) ?? channel.id
        if !identifier.hasPrefix("entry-") {
            return "channel|\(identifier.lowercased())"
        }
        let name = channel.name.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "channel|\(channel.countryCode.lowercased())|\(name)"
    }

    private func merge(_ first: Channel, with second: Channel, id: String) -> Channel {
        Channel(
            id: id,
            name: first.name,
            alternativeNames: Array(Set(first.alternativeNames + second.alternativeNames + [second.name])).filter { $0 != first.name }.sorted(),
            countryCode: first.countryCode == "ZZ" ? second.countryCode : first.countryCode,
            categoryIDs: Array(Set(first.categoryIDs + second.categoryIDs)).sorted(),
            isNSFW: first.isNSFW || second.isNSFW,
            network: first.network ?? second.network,
            owners: Array(Set(first.owners + second.owners)).sorted(),
            launched: first.launched ?? second.launched,
            closed: first.closed ?? second.closed,
            replacedBy: first.replacedBy ?? second.replacedBy,
            website: first.website ?? second.website
        )
    }

    private func emptyCatalog() -> Catalog { Catalog(channels: [], countries: [], categories: [], streamsByChannelID: [:], logosByChannelID: [:]) }
}
