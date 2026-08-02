import Foundation

enum APIEndpoint: String, CaseIterable, Sendable {
    case channels
    case streams
    case logos
    case countries
    case categories
    case blocklist
    case feeds
    case languages

    var url: URL? {
        URL(string: "https://iptv-org.github.io/api/\(rawValue).json")
    }
}
