#if os(tvOS)
import XCTest
@testable import WorldTV

final class TVNavigationCoordinatorTests: XCTestCase {
    func testOpeningSourcesReturnsToRootAndTargetsSettingsSources() {
        let coordinator = TVNavigationCoordinator(selectedSection: .home)
        coordinator.path = [.about]

        coordinator.open(.sources)

        XCTAssertEqual(coordinator.path, [])
        XCTAssertEqual(coordinator.selectedSection, .settings)
        XCTAssertEqual(coordinator.settingsFocusTarget, .sources)
    }

    func testSelectingAnotherSectionClearsSettingsFocusTarget() {
        let coordinator = TVNavigationCoordinator(selectedSection: .settings)
        coordinator.settingsFocusTarget = .sources

        coordinator.didSelectSection(.home)

        XCTAssertEqual(coordinator.selectedSection, .home)
        XCTAssertNil(coordinator.settingsFocusTarget)
    }

    func testOpeningCountrySearchUsesSearchAsTopLevelSection() {
        let coordinator = TVNavigationCoordinator(selectedSection: .home)

        coordinator.open(.searchCountry("ES"))

        XCTAssertEqual(coordinator.selectedSection, .search)
        XCTAssertEqual(coordinator.searchRequest?.countryCode, "ES")
        XCTAssertNil(coordinator.searchRequest?.categoryID)
    }

    func testPoppingCountryRestoresCountryFocus() {
        let coordinator = TVNavigationCoordinator(selectedSection: .countries)
        let oldGeneration = coordinator.countryFocusReturn.generation

        coordinator.didChangePath(from: [.country("ES")], to: [])

        XCTAssertEqual(coordinator.countryFocusReturn.code, "ES")
        XCTAssertEqual(
            coordinator.countryFocusReturn.generation,
            oldGeneration + 1
        )
    }
}
#endif
