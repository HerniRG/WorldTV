import Foundation

struct LoadHomeContentUseCase: Sendable {
    private let repository: any ChannelRepository
    private let recentlyWatchedRepository: any RecentlyWatchedRepository
    private let favoritesRepository: any FavoritesRepository

    init(
        repository: any ChannelRepository,
        recentlyWatchedRepository: any RecentlyWatchedRepository,
        favoritesRepository: any FavoritesRepository
    ) {
        self.repository = repository
        self.recentlyWatchedRepository = recentlyWatchedRepository
        self.favoritesRepository = favoritesRepository
    }

    func execute(forceRefresh: Bool = false) async throws -> HomeContent {
        let catalog = try await repository.loadCatalog(forceRefresh: forceRefresh)
        let history: [RecentlyWatchedChannel]
        do {
            history = try await recentlyWatchedRepository.load()
        } catch {
            history = []
        }
        let favoriteIdentifiers: [String]
        do {
            favoriteIdentifiers = try await favoritesRepository.load()
        } catch {
            favoriteIdentifiers = []
        }
        let countries = catalog.countries.compactMap { country -> CountryCatalogItem? in
            let count = catalog.index.channels(countryCode: country.code).count
            return count == 0 ? nil : CountryCatalogItem(country: country, channelCount: count)
        }
        .sorted {
            if $0.channelCount == $1.channelCount {
                return $0.country.name.localizedStandardCompare($1.country.name) == .orderedAscending
            }
            return $0.channelCount > $1.channelCount
        }

        let featured = catalog.channels.lazy
            .filter { catalog.streamsByChannelID[$0.id]?.isEmpty == false }
            .filter { catalog.index.preferredLogoByChannelID[$0.id] != nil }
            .prefix(20)
            .map { makeChannelItem($0, catalog: catalog) }
        let recentlyWatched = history.compactMap { entry in
            catalog.index.channelsByID[entry.channelID]
        }
        .map { makeChannelItem($0, catalog: catalog) }
        let favorites = favoriteIdentifiers.compactMap { identifier in
            catalog.index.channelsByID[identifier]
        }
        .map { makeChannelItem($0, catalog: catalog) }

        return HomeContent(
            summary: catalog.summary,
            favoriteChannels: favorites,
            recentlyWatched: recentlyWatched,
            featuredChannels: Array(featured),
            popularCountries: Array(countries.prefix(12)),
            categories: Array(catalog.categories.prefix(12))
        )
    }
}

struct LoadCountriesUseCase: Sendable {
    private let repository: any ChannelRepository

    init(repository: any ChannelRepository) {
        self.repository = repository
    }

    func execute() async throws -> [CountryCatalogItem] {
        let catalog = try await repository.loadCatalog()
        return catalog.countries.compactMap { country in
            let count = catalog.index.channels(countryCode: country.code).count
            return count == 0 ? nil : CountryCatalogItem(country: country, channelCount: count)
        }
        .sorted {
            $0.country.name.localizedStandardCompare($1.country.name) == .orderedAscending
        }
    }
}

struct LoadChannelsByCountryUseCase: Sendable {
    private let repository: any ChannelRepository

    init(repository: any ChannelRepository) {
        self.repository = repository
    }

    func execute(countryCode: String) async throws -> CountryChannels? {
        let catalog = try await repository.loadCatalog()
        guard let country = catalog.index.countryByCode[countryCode] else {
            return nil
        }

        let channels = catalog.index.channels(countryCode: countryCode)
            .map { makeChannelItem($0, catalog: catalog) }
            .sorted {
                $0.channel.name.localizedStandardCompare($1.channel.name) == .orderedAscending
            }
        return CountryChannels(country: country, channels: channels)
    }
}

func makeChannelCatalogItem(_ channel: Channel, catalog: Catalog) -> ChannelCatalogItem {
    let streams = catalog.streamsByChannelID[channel.id] ?? []
    return ChannelCatalogItem(
        channel: channel,
        logo: catalog.index.preferredLogoByChannelID[channel.id],
        countryName: catalog.index.countryByCode[channel.countryCode]?.name
            ?? channel.countryCode,
        isAvailable: !streams.isEmpty,
        isGeoBlocked: streams.contains { stream in
            stream.label?.localizedCaseInsensitiveContains("geo") == true
        },
        quality: streams.compactMap(\.quality).sorted().last
    )
}

private func makeChannelItem(_ channel: Channel, catalog: Catalog) -> ChannelCatalogItem {
    makeChannelCatalogItem(channel, catalog: catalog)
}
