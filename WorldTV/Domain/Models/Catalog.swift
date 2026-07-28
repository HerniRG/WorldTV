import Foundation

struct Catalog: Sendable {
    let channels: [Channel]
    let countries: [Country]
    let categories: [ChannelCategory]
    let streamsByChannelID: [String: [ChannelStream]]
    let logosByChannelID: [String: [ChannelLogo]]

    var summary: CatalogSummary {
        CatalogSummary(
            countryCount: Set(channels.map(\.countryCode)).count,
            channelCount: channels.count,
            playableChannelCount: streamsByChannelID.values.lazy.filter { !$0.isEmpty }.count
        )
    }
}

struct CatalogSummary: Equatable, Sendable {
    let countryCount: Int
    let channelCount: Int
    let playableChannelCount: Int
}
