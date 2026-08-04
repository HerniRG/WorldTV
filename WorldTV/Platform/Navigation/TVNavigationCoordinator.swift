#if os(tvOS)
import Foundation
import Observation

@Observable
final class TVNavigationCoordinator {
    var selectedSection: AppSection
    var path: [AppRoute] = []
    var searchRequest: TVSearchRequest?
    var settingsFocusTarget: SettingsFocusTarget?
    var countryFocusReturn = CountryFocusReturn()

    init(selectedSection: AppSection = .home) {
        self.selectedSection = selectedSection
    }

    func restoreSection(rawValue: String) {
        selectedSection = AppSection(rawValue: rawValue) ?? .home
    }

    func didSelectSection(_ section: AppSection) {
        selectedSection = section
        if section != .settings {
            settingsFocusTarget = nil
        }
    }

    func open(_ destination: TVTopLevelDestination) {
        path.removeAll()

        switch destination {
        case .section(let section):
            didSelectSection(section)
        case .sources:
            settingsFocusTarget = .sources
            selectedSection = .settings
        case .searchCategory(let categoryID):
            searchRequest = TVSearchRequest(categoryID: categoryID)
            didSelectSection(.search)
        case .searchCountry(let countryCode):
            searchRequest = TVSearchRequest(countryCode: countryCode)
            didSelectSection(.search)
        }
    }

    func didChangePath(from oldPath: [AppRoute], to newPath: [AppRoute]) {
        guard
            newPath.count < oldPath.count,
            case .country(let code) = oldPath.last
        else {
            return
        }

        countryFocusReturn = CountryFocusReturn(
            code: code,
            generation: countryFocusReturn.generation + 1
        )
    }
}
#endif
