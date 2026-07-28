import Foundation

struct LoadHomeContentUseCase: Sendable {
    private let repository: any ChannelRepository

    init(repository: any ChannelRepository) {
        self.repository = repository
    }

    func execute(forceRefresh: Bool = false) async throws -> HomeContent {
        let catalog = try await repository.loadCatalog(forceRefresh: forceRefresh)
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

        return HomeContent(
            summary: catalog.summary,
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

private func makeChannelItem(_ channel: Channel, catalog: Catalog) -> ChannelCatalogItem {
    let streams = catalog.streamsByChannelID[channel.id] ?? []
    return ChannelCatalogItem(
        channel: channel,
        logo: catalog.index.preferredLogoByChannelID[channel.id],
        isAvailable: !streams.isEmpty,
        quality: streams.compactMap(\.quality).sorted().last
    )
}
