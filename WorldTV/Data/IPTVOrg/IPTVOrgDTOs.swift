import Foundation

struct IPTVOrgChannelDTO: Codable, Sendable {
    let id: String
    let name: String
    let alternativeNames: [String]
    let country: String
    let categories: [String]
    let isNSFW: Bool
    let closed: String?
    var network: String? = nil
    var owners: [String] = []

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case alternativeNames = "alt_names"
        case country
        case categories
        case isNSFW = "is_nsfw"
        case closed
        case network
        case owners
    }
}

struct IPTVOrgStreamDTO: Codable, Sendable {
    let channel: String?
    let feed: String?
    let title: String?
    let url: String
    let referrer: String?
    let userAgent: String?
    let quality: String?
    let label: String?

    enum CodingKeys: String, CodingKey {
        case channel
        case feed
        case title
        case url
        case referrer
        case userAgent = "user_agent"
        case quality
        case label
    }
}

struct IPTVOrgLogoDTO: Codable, Sendable {
    let channel: String?
    let feed: String?
    let url: String
    let width: Int?
    let height: Int?
    let format: String?
    let isInUse: Bool
    var tags: [String] = []

    enum CodingKeys: String, CodingKey {
        case channel
        case feed
        case url
        case width
        case height
        case format
        case isInUse = "in_use"
        case tags
    }
}

struct IPTVOrgCountryDTO: Codable, Sendable {
    let code: String
    let name: String
    let languages: [String]
    let flag: String?
}

struct IPTVOrgCategoryDTO: Codable, Sendable {
    let id: String
    let name: String
}

struct IPTVOrgBlocklistDTO: Codable, Sendable {
    let channel: String
}

struct IPTVOrgFeedDTO: Codable, Sendable {
    let channel: String?
    let id: String
    let name: String?
    let isMain: Bool?
    var languages: [String] = []

    enum CodingKeys: String, CodingKey {
        case channel
        case id
        case name
        case isMain = "is_main"
        case languages
    }
}

struct IPTVOrgLanguageDTO: Codable, Sendable {
    let name: String
    let code: String
}

struct IPTVOrgCatalogPayload: Codable, Sendable {
    let channels: [IPTVOrgChannelDTO]
    let streams: [IPTVOrgStreamDTO]
    let logos: [IPTVOrgLogoDTO]
    let countries: [IPTVOrgCountryDTO]
    let categories: [IPTVOrgCategoryDTO]
    let blocklist: [IPTVOrgBlocklistDTO]
    var feeds: [IPTVOrgFeedDTO] = []
    var languages: [IPTVOrgLanguageDTO] = []
}

extension IPTVOrgChannelDTO {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        alternativeNames = try container.decode([String].self, forKey: .alternativeNames)
        country = try container.decode(String.self, forKey: .country)
        categories = try container.decode([String].self, forKey: .categories)
        isNSFW = try container.decode(Bool.self, forKey: .isNSFW)
        closed = try container.decodeIfPresent(String.self, forKey: .closed)
        network = try container.decodeIfPresent(String.self, forKey: .network)
        owners = try container.decodeIfPresent([String].self, forKey: .owners) ?? []
    }
}

extension IPTVOrgLogoDTO {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channel = try container.decodeIfPresent(String.self, forKey: .channel)
        feed = try container.decodeIfPresent(String.self, forKey: .feed)
        url = try container.decode(String.self, forKey: .url)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        format = try container.decodeIfPresent(String.self, forKey: .format)
        isInUse = try container.decode(Bool.self, forKey: .isInUse)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

extension IPTVOrgFeedDTO {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channel = try container.decodeIfPresent(String.self, forKey: .channel)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        isMain = try container.decodeIfPresent(Bool.self, forKey: .isMain)
        languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? []
    }
}

extension IPTVOrgCatalogPayload {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        channels = try container.decode([IPTVOrgChannelDTO].self, forKey: .channels)
        streams = try container.decode([IPTVOrgStreamDTO].self, forKey: .streams)
        logos = try container.decode([IPTVOrgLogoDTO].self, forKey: .logos)
        countries = try container.decode([IPTVOrgCountryDTO].self, forKey: .countries)
        categories = try container.decode([IPTVOrgCategoryDTO].self, forKey: .categories)
        blocklist = try container.decode([IPTVOrgBlocklistDTO].self, forKey: .blocklist)
        feeds = try container.decodeIfPresent([IPTVOrgFeedDTO].self, forKey: .feeds) ?? []
        languages = try container.decodeIfPresent([IPTVOrgLanguageDTO].self, forKey: .languages) ?? []
    }
}
