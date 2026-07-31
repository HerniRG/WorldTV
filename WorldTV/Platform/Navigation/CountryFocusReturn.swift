import SwiftUI

struct CountryFocusReturn: Equatable {
    var code: String?
    var generation = 0
}

private struct CountryFocusReturnKey: EnvironmentKey {
    static let defaultValue = CountryFocusReturn()
}

extension EnvironmentValues {
    var countryFocusReturn: CountryFocusReturn {
        get { self[CountryFocusReturnKey.self] }
        set { self[CountryFocusReturnKey.self] = newValue }
    }
}
