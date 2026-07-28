import Foundation
@testable import WorldTV

enum IPTVOrgFixtures {
    static let channelsJSON = Data("""
    [
      {
        "id": "News.es",
        "name": "News",
        "alt_names": ["Noticias"],
        "country": "ES",
        "categories": ["news"],
        "is_nsfw": false,
        "closed": null
      }
    ]
    """.utf8)

    static let streamsJSON = Data("""
    [
      {
        "channel": "News.es",
        "feed": null,
        "title": "News HD",
        "url": "https://example.com/live.m3u8",
        "http_referrer": null,
        "user_agent": null,
        "quality": "1080p",
        "label": null
      }
    ]
    """.utf8)

    static var catalogPayload: IPTVOrgCatalogPayload {
        IPTVOrgCatalogPayload(
            channels: [
                channel(id: "News.es", name: "News", country: "ES"),
                channel(id: "Adult.es", name: "Adult", country: "ES", isNSFW: true),
                channel(id: "Closed.es", name: "Closed", country: "ES", closed: "2025-01-01"),
                channel(id: "Blocked.es", name: "Blocked", country: "ES")
            ],
            streams: [
                stream(channel: "News.es", url: "https://example.com/live.m3u8"),
                stream(channel: "News.es", url: "http://example.com/insecure.m3u8"),
                stream(channel: "Missing.es", url: "https://example.com/orphan.m3u8"),
                stream(channel: nil, url: "https://example.com/unassigned.m3u8")
            ],
            logos: [
                logo(channel: "News.es", url: "https://example.com/news.png"),
                logo(channel: "Missing.es", url: "https://example.com/orphan.png")
            ],
            countries: [
                IPTVOrgCountryDTO(code: "ES", name: "Spain", languages: ["spa"], flag: "🇪🇸")
            ],
            categories: [
                IPTVOrgCategoryDTO(id: "news", name: "News")
            ],
            blocklist: [
                IPTVOrgBlocklistDTO(channel: "Blocked.es")
            ]
        )
    }

    private static func channel(
        id: String,
        name: String,
        country: String,
        isNSFW: Bool = false,
        closed: String? = nil
    ) -> IPTVOrgChannelDTO {
        IPTVOrgChannelDTO(
            id: id,
            name: name,
            alternativeNames: [],
            country: country,
            categories: ["news"],
            isNSFW: isNSFW,
            closed: closed
        )
    }

    private static func stream(channel: String?, url: String) -> IPTVOrgStreamDTO {
        IPTVOrgStreamDTO(
            channel: channel,
            feed: nil,
            title: nil,
            url: url,
            referrer: nil,
            userAgent: nil,
            quality: "1080p",
            label: nil
        )
    }

    private static func logo(channel: String?, url: String) -> IPTVOrgLogoDTO {
        IPTVOrgLogoDTO(
            channel: channel,
            feed: nil,
            url: url,
            width: 512,
            height: 288,
            format: "PNG",
            isInUse: true
        )
    }
}
