import Testing
@testable import WorldTV

struct AppSectionTests {
    @Test
    func sectionsHaveStablePersistentIdentifiers() {
        #expect(
            AppSection.allCases.map(\.rawValue)
                == ["home", "countries", "search", "favorites", "settings"]
        )
        #expect(AppSection(rawValue: "home") == .home)
        #expect(AppSection(rawValue: "countries") == .countries)
    }

    @Test
    func sectionsExposeDistinctNavigationMetadata() {
        #expect(
            Set(AppSection.allCases.map(\.localizationKey)).count
                == AppSection.allCases.count
        )
        #expect(Set(AppSection.allCases.map(\.systemImage)).count == AppSection.allCases.count)
    }
}
