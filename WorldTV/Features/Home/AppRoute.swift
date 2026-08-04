import Foundation

enum AppRoute: Hashable {
    case countries
    case favorites
    case sources
    case search
    case searchCategory(String)
    case about
    case country(String)
    case category(String)
    case channel(String)
    case network(String)
}
