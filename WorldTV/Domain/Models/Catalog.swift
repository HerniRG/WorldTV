import Foundation

struct Catalog: Sendable {
    let channels: [Channel]
    let countries: [Country]
    let categories: [ChannelCategory]
    let streamsByChannelID: [String: [ChannelStream]]
    let logosByChannelID: [String: [ChannelLogo]]
    let index: CatalogIndex

    init(
        channels: [Channel],
        countries: [Country],
        categories: [ChannelCategory],
        streamsByChannelID: [String: [ChannelStream]],
        logosByChannelID: [String: [ChannelLogo]]
    ) {
        self.channels = channels
        self.countries = countries
        self.categories = categories
        self.streamsByChannelID = streamsByChannelID
        self.logosByChannelID = logosByChannelID
        index = CatalogIndex(
            channels: channels,
            countries: countries,
            logosByChannelID: logosByChannelID
        )
    }

    var summary: CatalogSummary {
        CatalogSummary(
            countryCount: Set(channels.map(\.countryCode)).count,
            channelCount: channels.count,
            playableChannelCount: streamsByChannelID.values.lazy.filter { !$0.isEmpty }.count
        )
    }
}

struct CountryCatalogItem: Identifiable, Hashable, Sendable {
    var id: String { country.id }

    let country: Country
    let channelCount: Int
}

struct ChannelCatalogItem: Identifiable, Hashable, Sendable {
    var id: String { channel.id }

    let channel: Channel
    let logo: ChannelLogo?
    let isAvailable: Bool
    let quality: String?
}

struct HomeContent: Sendable {
    let summary: CatalogSummary
    let featuredChannels: [ChannelCatalogItem]
    let popularCountries: [CountryCatalogItem]
    let categories: [ChannelCategory]
}

struct CountryChannels: Sendable {
    let country: Country
    let channels: [ChannelCatalogItem]
}

struct CatalogSummary: Equatable, Sendable {
    let countryCount: Int
    let channelCount: Int
    let playableChannelCount: Int
}
