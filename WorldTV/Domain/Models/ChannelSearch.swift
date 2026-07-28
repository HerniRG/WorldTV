import Foundation

struct ChannelSearchCriteria: Equatable, Sendable {
    var query = ""
    var countryCode: String?
    var categoryID: String?
    var minimumQuality: Int?
    var favoritesOnly = false
    var availableOnly = true
    var includeGeoBlocked = true
}

struct ChannelSearchOptions: Sendable {
    let countries: [Country]
    let categories: [ChannelCategory]
}

struct ChannelSearchResult: Sendable {
    let channels: [ChannelCatalogItem]
    let options: ChannelSearchOptions
}
