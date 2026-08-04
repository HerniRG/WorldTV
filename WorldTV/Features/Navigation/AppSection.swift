import Foundation

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case home
    case countries
    case search
    case favorites
    case sources
    case settings

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .home:
            "navigation.home"
        case .countries:
            "countries.title"
        case .search:
            "search.title"
        case .favorites:
            "favorites.title"
        case .sources:
            "sources.title"
        case .settings:
            "settings.title"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .countries:
            "globe.europe.africa"
        case .search:
            "magnifyingglass"
        case .favorites:
            "star"
        case .sources:
            "list.bullet.rectangle"
        case .settings:
            "gear"
        }
    }
}
