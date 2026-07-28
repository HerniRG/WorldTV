import Foundation

struct SearchChannelsUseCase: Sendable {
    private let channelRepository: any ChannelRepository
    private let favoritesRepository: any FavoritesRepository
    private let maximumResults: Int

    init(
        channelRepository: any ChannelRepository,
        favoritesRepository: any FavoritesRepository,
        maximumResults: Int = 500
    ) {
        self.channelRepository = channelRepository
        self.favoritesRepository = favoritesRepository
        self.maximumResults = maximumResults
    }

    func execute(criteria: ChannelSearchCriteria) async throws -> ChannelSearchResult {
        async let catalog = channelRepository.loadCatalog()
        async let favoriteIdentifiers = favoritesRepository.load()
        let (loadedCatalog, loadedFavorites) = try await (catalog, favoriteIdentifiers)
        let favoriteSet = Set(loadedFavorites)
        let normalizedQuery = criteria.query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let channels = loadedCatalog.channels.lazy.filter { channel in
            let streams = loadedCatalog.streamsByChannelID[channel.id] ?? []
            if criteria.availableOnly && streams.isEmpty {
                return false
            }
            if criteria.favoritesOnly && !favoriteSet.contains(channel.id) {
                return false
            }
            if let countryCode = criteria.countryCode, channel.countryCode != countryCode {
                return false
            }
            if
                let categoryID = criteria.categoryID,
                !channel.categoryIDs.contains(categoryID)
            {
                return false
            }
            if
                !criteria.includeGeoBlocked,
                streams.contains(where: {
                    $0.label?.localizedCaseInsensitiveContains("geo") == true
                })
            {
                return false
            }
            if let minimumQuality = criteria.minimumQuality {
                let maximumQuality = streams.compactMap {
                    Self.qualityValue($0.quality)
                }
                .max() ?? 0
                if maximumQuality < minimumQuality {
                    return false
                }
            }
            guard !normalizedQuery.isEmpty else {
                return true
            }
            return Self.matches(
                channel: channel,
                streams: streams,
                catalog: loadedCatalog,
                query: normalizedQuery
            )
        }
        .prefix(maximumResults)
        .map { makeChannelCatalogItem($0, catalog: loadedCatalog) }
        .sorted {
            $0.channel.name.localizedStandardCompare($1.channel.name)
                == .orderedAscending
        }

        return ChannelSearchResult(
            channels: channels,
            options: ChannelSearchOptions(
                countries: loadedCatalog.countries.sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                },
                categories: loadedCatalog.categories.sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
            )
        )
    }

    private static func matches(
        channel: Channel,
        streams: [ChannelStream],
        catalog: Catalog,
        query: String
    ) -> Bool {
        if channel.name.localizedCaseInsensitiveContains(query) {
            return true
        }
        if channel.alternativeNames.contains(where: {
            $0.localizedCaseInsensitiveContains(query)
        }) {
            return true
        }
        if
            catalog.index.countryByCode[channel.countryCode]?.name
                .localizedCaseInsensitiveContains(query) == true
        {
            return true
        }
        if channel.categoryIDs.contains(where: { identifier in
            catalog.categories.first(where: { $0.id == identifier })?.name
                .localizedCaseInsensitiveContains(query) == true
        }) {
            return true
        }
        return streams.contains {
            $0.title?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private static func qualityValue(_ quality: String?) -> Int? {
        guard let quality else {
            return nil
        }
        return Int(quality.filter(\.isNumber))
    }
}
