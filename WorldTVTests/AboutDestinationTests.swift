import Foundation
import Testing
@testable import WorldTV

struct AboutDestinationTests {
    @Test
    func destinationsAreSecureAndValid() {
        #expect(AboutDestination.allCases.count == 6)

        for destination in AboutDestination.allCases {
            #expect(destination.url?.scheme == "https")
            #expect(destination.url?.host() != nil)
        }
    }

    @Test
    func privacyPolicyUsesThePublishedRepositoryDocument() {
        #expect(
            AboutDestination.privacy.url?.absoluteString
                == "https://github.com/HerniRG/WorldTV/blob/main/PRIVACY.md"
        )
    }
}
