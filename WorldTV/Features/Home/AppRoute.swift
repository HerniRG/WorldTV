import Foundation

enum AppRoute: Hashable {
    case countries
    case favorites
    case search
    case searchCategory(String)
    case about
    case country(String)
}
