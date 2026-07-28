import Foundation

struct CatalogIndex: Sendable {
    let channelsByID: [String: Channel]
    let channelsByCountryCode: [String: [Channel]]
    let preferredLogoByChannelID: [String: ChannelLogo]
    let countryByCode: [String: Country]

    init(
        channels: [Channel],
        countries: [Country],
        logosByChannelID: [String: [ChannelLogo]]
    ) {
        channelsByID = Dictionary(uniqueKeysWithValues: channels.map { ($0.id, $0) })
        channelsByCountryCode = Dictionary(grouping: channels, by: \.countryCode)
        countryByCode = Dictionary(uniqueKeysWithValues: countries.map { ($0.code, $0) })
        preferredLogoByChannelID = logosByChannelID.compactMapValues { logos in
            logos.sorted(by: Self.isPreferredLogo).first
        }
    }

    func channels(countryCode: String) -> [Channel] {
        channelsByCountryCode[countryCode] ?? []
    }

    private static func isPreferredLogo(_ lhs: ChannelLogo, _ rhs: ChannelLogo) -> Bool {
        if lhs.isInUse != rhs.isInUse {
            return lhs.isInUse
        }

        let lhsIsHorizontal = (lhs.width ?? 0) >= (lhs.height ?? 0)
        let rhsIsHorizontal = (rhs.width ?? 0) >= (rhs.height ?? 0)
        if lhsIsHorizontal != rhsIsHorizontal {
            return lhsIsHorizontal
        }

        return (lhs.width ?? 0) * (lhs.height ?? 0) > (rhs.width ?? 0) * (rhs.height ?? 0)
    }
}
