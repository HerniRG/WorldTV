import Foundation

struct IPTVOrgChannelDTO: Codable, Sendable {
    let id: String
    let name: String
    let alternativeNames: [String]
    let country: String
    let categories: [String]
    let isNSFW: Bool
    let closed: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case alternativeNames = "alt_names"
        case country
        case categories
        case isNSFW = "is_nsfw"
        case closed
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

    enum CodingKeys: String, CodingKey {
        case channel
        case feed
        case url
        case width
        case height
        case format
        case isInUse = "in_use"
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

struct IPTVOrgCatalogPayload: Codable, Sendable {
    let channels: [IPTVOrgChannelDTO]
    let streams: [IPTVOrgStreamDTO]
    let logos: [IPTVOrgLogoDTO]
    let countries: [IPTVOrgCountryDTO]
    let categories: [IPTVOrgCategoryDTO]
    let blocklist: [IPTVOrgBlocklistDTO]
}
