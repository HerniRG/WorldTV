import Foundation

struct CatalogIndex: Sendable {
    let channelsByID: [String: Channel]
    let channelsByCountryCode: [String: [Channel]]
    let preferredLogoByChannelID: [String: ChannelLogo]
    let countryByCode: [String: Country]
    let feedsByChannelID: [String: [ChannelFeed]]
    let languageCodesByChannelID: [String: Set<String>]
    let channelsByBroadcaster: [String: [Channel]]

    init(
        channels: [Channel],
        countries: [Country],
        logosByChannelID: [String: [ChannelLogo]],
        feeds: [ChannelFeed] = []
    ) {
        channelsByID = Dictionary(uniqueKeysWithValues: channels.map { ($0.id, $0) })
        channelsByCountryCode = Dictionary(grouping: channels, by: \.countryCode)
        let countriesByCode = Dictionary(uniqueKeysWithValues: countries.map { ($0.code, $0) })
        countryByCode = countriesByCode
        preferredLogoByChannelID = logosByChannelID.compactMapValues { logos in
            logos.sorted(by: Self.isPreferredLogo).first
        }
        let groupedFeeds = Dictionary(grouping: feeds, by: \.channelID).mapValues { feeds in
            feeds.sorted {
                if $0.isMain != $1.isMain {
                    return $0.isMain
                }
                return ($0.name ?? "") < ($1.name ?? "")
            }
        }
        feedsByChannelID = groupedFeeds
        languageCodesByChannelID = channels.reduce(into: [:]) { result, channel in
            let feedLanguages = groupedFeeds[channel.id]?.flatMap(\.languages) ?? []
            if !feedLanguages.isEmpty {
                result[channel.id] = Set(feedLanguages)
                return
            }
            if let countryLanguages = countriesByCode[channel.countryCode]?.languageCodes {
                result[channel.id] = Set(countryLanguages)
            }
        }
        channelsByBroadcaster = Dictionary(grouping: channels, by: \.broadcasterName)
            .filter { !$0.key.isEmpty }
    }

    func channels(countryCode: String) -> [Channel] {
        channelsByCountryCode[countryCode] ?? []
    }

    private static func isPreferredLogo(_ lhs: ChannelLogo, _ rhs: ChannelLogo) -> Bool {
        if lhs.isInUse != rhs.isInUse {
            return lhs.isInUse
        }

        let lhsHasHorizontalTag = lhs.tags.contains { $0.caseInsensitiveCompare("horizontal") == .orderedSame }
        let rhsHasHorizontalTag = rhs.tags.contains { $0.caseInsensitiveCompare("horizontal") == .orderedSame }
        if lhsHasHorizontalTag != rhsHasHorizontalTag {
            return lhsHasHorizontalTag
        }

        let lhsPixels = (lhs.width ?? 0) * (lhs.height ?? 0)
        let rhsPixels = (rhs.width ?? 0) * (rhs.height ?? 0)

        let lhsFormatPriority = Self.formatPriority(lhs.format)
        let rhsFormatPriority = Self.formatPriority(rhs.format)

        // Prefer higher format (SVG > WebP > AVIF > PNG > JPEG) only if its resolution
        // is at least 90% of the lower format's resolution. This prevents smaller
        // vector images from winning over larger, higher-quality raster images.
        if lhsFormatPriority != rhsFormatPriority {
            let higherFormatIsLHS = lhsFormatPriority > rhsFormatPriority
            let higherFormatPixels = higherFormatIsLHS ? lhsPixels : rhsPixels
            let lowerFormatPixels = higherFormatIsLHS ? rhsPixels : lhsPixels

            if lowerFormatPixels > 0 && higherFormatPixels * 10 >= lowerFormatPixels * 9 {
                // higher format has at least 90% of lower format's resolution
                return higherFormatIsLHS
            }
            return !higherFormatIsLHS
        }

        let lhsIsHorizontal = (lhs.width ?? 0) >= (lhs.height ?? 0)
        let rhsIsHorizontal = (rhs.width ?? 0) >= (rhs.height ?? 0)
        if lhsIsHorizontal != rhsIsHorizontal {
            return lhsIsHorizontal
        }

        return lhsPixels > rhsPixels
    }

    private static func formatPriority(_ format: String?) -> Int {
        guard let format = format?.uppercased() else { return 0 }
        switch format {
        case "SVG": return 5
        case "WEBP": return 4
        case "AVIF": return 3
        case "PNG": return 2
        case "JPEG", "JPG": return 1
        default: return 0
        }
    }
}
