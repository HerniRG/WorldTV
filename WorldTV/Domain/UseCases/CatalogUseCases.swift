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
        let categories = catalog.categories.compactMap { category -> CategoryCatalogItem? in
            let count = catalog.channels.lazy.filter {
                $0.categoryIDs.contains(category.id)
            }.count
            return count == 0 ? nil : CategoryCatalogItem(category: category, channelCount: count)
        }
        .sorted {
            $0.category.name.localizedStandardCompare($1.category.name) == .orderedAscending
        }
        let broadcasters = catalog.index.channelsByBroadcaster.map { name, channels in
            BroadcasterCatalogItem(
                id: name,
                name: name,
                channelCount: channels.count,
                logos: channels.prefix(4).compactMap {
                    catalog.index.preferredLogoByChannelID[$0.id]
                }
            )
        }
        .sorted {
            if $0.channelCount == $1.channelCount {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.channelCount > $1.channelCount
        }

        let featuredChannels = catalog.channels.lazy
            .filter { catalog.streamsByChannelID[$0.id]?.isEmpty == false }
            .filter { catalog.index.preferredLogoByChannelID[$0.id] != nil }
            .prefix(20)

        let featured: [ChannelCatalogItem] = featuredChannels.map {
            makeChannelCatalogItem($0, catalog: catalog)
        }

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
            categories: Array(categories.prefix(12)),
            broadcasters: Array(broadcasters.prefix(12))
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

struct LoadCategoriesUseCase: Sendable {
    private let repository: any ChannelRepository

    init(repository: any ChannelRepository) {
        self.repository = repository
    }

    func execute() async throws -> [CategoryCatalogItem] {
        let catalog = try await repository.loadCatalog()
        return catalog.categories.compactMap { category -> CategoryCatalogItem? in
            let count = catalog.channels.lazy.filter {
                $0.categoryIDs.contains(category.id)
            }.count
            return count == 0 ? nil : CategoryCatalogItem(category: category, channelCount: count)
        }
        .sorted {
            $0.category.name.localizedStandardCompare($1.category.name) == .orderedAscending
        }
    }
}

struct LoadChannelsByCategoryUseCase: Sendable {
    private let repository: any ChannelRepository

    init(repository: any ChannelRepository) {
        self.repository = repository
    }

    func execute(categoryID: String) async throws -> CategoryChannels? {
        let catalog = try await repository.loadCatalog()
        guard let category = catalog.categories.first(where: { $0.id == categoryID }) else {
            return nil
        }

        let channels = catalog.channels
            .filter { $0.categoryIDs.contains(categoryID) }
            .map { makeChannelItem($0, catalog: catalog) }
            .sorted {
                $0.channel.name.localizedStandardCompare($1.channel.name) == .orderedAscending
            }
        return CategoryChannels(category: category, channels: channels)
    }
}

struct LoadChannelsByBroadcasterUseCase: Sendable {
    private let repository: any ChannelRepository

    init(repository: any ChannelRepository) {
        self.repository = repository
    }

    func execute(broadcasterID: String) async throws -> BroadcasterChannels? {
        let catalog = try await repository.loadCatalog()
        guard
            let channels = catalog.index.channelsByBroadcaster[broadcasterID],
            !channels.isEmpty
        else {
            return nil
        }
        let items = channels
            .map { makeChannelItem($0, catalog: catalog) }
            .sorted {
                $0.channel.name.localizedStandardCompare($1.channel.name) == .orderedAscending
            }
        return BroadcasterChannels(
            broadcaster: BroadcasterCatalogItem(
                id: broadcasterID,
                name: broadcasterID,
                channelCount: channels.count,
                logos: channels.prefix(4).compactMap {
                    catalog.index.preferredLogoByChannelID[$0.id]
                }
            ),
            channels: items
        )
    }
}

struct LoadChannelDetailUseCase: Sendable {
    private let repository: any ChannelRepository

    init(
        repository: any ChannelRepository
    ) {
        self.repository = repository
    }

    func execute(channelID: String) async throws -> ChannelDetailContent? {
        let catalog = try await repository.loadCatalog()
        guard let channel = catalog.index.channelsByID[channelID] else {
            return nil
        }
        let streams = catalog.streamsByChannelID[channelID] ?? []
        let blocklistEntry = catalog.blocklist.first { $0.channelID == channelID }
        let feeds = catalog.index.feedsByChannelID[channelID] ?? []
        return ChannelDetailContent(
            channel: channel,
            logo: catalog.index.preferredLogoByChannelID[channelID],
            logos: catalog.index.logoCandidatesByChannelID[channelID] ?? [],
            countryName: catalog.index.countryByCode[channel.countryCode]?.name
                ?? channel.countryCode,
            categoryNames: channel.categoryIDs.compactMap { id in
                catalog.categories.first(where: { $0.id == id })?.name
            },
            isAvailable: !streams.isEmpty,
            isGeoBlocked: streams.contains { stream in
                stream.label?.localizedCaseInsensitiveContains("geo") == true
            },
            quality: streams.compactMap(\.quality).sorted().last,
            feeds: feeds,
            languages: catalog.languages,
            blocklistEntry: blocklistEntry
        )
    }
}

func makeChannelCatalogItem(
    _ channel: Channel,
    catalog: Catalog
) -> ChannelCatalogItem {
    let streams = catalog.streamsByChannelID[channel.id] ?? []
    return ChannelCatalogItem(
        channel: channel,
        logo: catalog.index.preferredLogoByChannelID[channel.id],
        logos: catalog.index.logoCandidatesByChannelID[channel.id] ?? [],
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
