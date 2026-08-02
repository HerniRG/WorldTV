import Foundation

struct Catalog: Sendable {
    let channels: [Channel]
    let countries: [Country]
    let categories: [ChannelCategory]
    let streamsByChannelID: [String: [ChannelStream]]
    let logosByChannelID: [String: [ChannelLogo]]
    let feeds: [ChannelFeed]
    let languages: [Language]
    let blocklist: [BlocklistEntry]
    let guides: [Guide]
    let index: CatalogIndex

    init(
        channels: [Channel],
        countries: [Country],
        categories: [ChannelCategory],
        streamsByChannelID: [String: [ChannelStream]],
        logosByChannelID: [String: [ChannelLogo]],
        feeds: [ChannelFeed] = [],
        languages: [Language] = [],
        blocklist: [BlocklistEntry] = [],
        guides: [Guide] = []
    ) {
        self.channels = channels
        self.countries = countries
        self.categories = categories
        self.streamsByChannelID = streamsByChannelID
        self.logosByChannelID = logosByChannelID
        self.feeds = feeds
        self.languages = languages
        self.blocklist = blocklist
        self.guides = guides
        index = CatalogIndex(
            channels: channels,
            countries: countries,
            logosByChannelID: logosByChannelID,
            feeds: feeds,
            guides: guides
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

struct CategoryCatalogItem: Identifiable, Hashable, Sendable {
    var id: String { category.id }

    let category: ChannelCategory
    let channelCount: Int
}

struct ChannelCatalogItem: Identifiable, Hashable, Sendable {
    var id: String { channel.id }

    let channel: Channel
    let logo: ChannelLogo?
    let logos: [ChannelLogo]
    let countryName: String
    let isAvailable: Bool
    let isGeoBlocked: Bool
    let quality: String?
    let nowPlaying: Program?
}

struct HomeContent: Sendable {
    let summary: CatalogSummary
    let favoriteChannels: [ChannelCatalogItem]
    let recentlyWatched: [ChannelCatalogItem]
    let featuredChannels: [ChannelCatalogItem]
    let popularCountries: [CountryCatalogItem]
    let categories: [CategoryCatalogItem]
    let broadcasters: [BroadcasterCatalogItem]
}

struct CountryChannels: Sendable {
    let country: Country
    let channels: [ChannelCatalogItem]
}

struct CategoryChannels: Sendable {
    let category: ChannelCategory
    let channels: [ChannelCatalogItem]
}

struct BroadcasterCatalogItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let channelCount: Int
    let logos: [ChannelLogo]
}

struct BroadcasterChannels: Sendable {
    let broadcaster: BroadcasterCatalogItem
    let channels: [ChannelCatalogItem]
}

struct ChannelDetailContent: Sendable {
    let channel: Channel
    let logo: ChannelLogo?
    let logos: [ChannelLogo]
    let countryName: String
    let categoryNames: [String]
    let isAvailable: Bool
    let isGeoBlocked: Bool
    let quality: String?
    let feeds: [ChannelFeed]
    let languages: [Language]
    let blocklistEntry: BlocklistEntry?
    let nowPlaying: Program?
}

struct CatalogSummary: Equatable, Sendable {
    let countryCount: Int
    let channelCount: Int
    let playableChannelCount: Int
}
