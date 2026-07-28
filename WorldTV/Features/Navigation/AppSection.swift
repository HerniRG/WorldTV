import Foundation

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case home
    case countries

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .home:
            "navigation.home"
        case .countries:
            "countries.title"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .countries:
            "globe.europe.africa"
        }
    }
}
