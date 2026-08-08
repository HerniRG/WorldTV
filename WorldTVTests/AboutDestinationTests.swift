import Foundation
import Testing
@testable import WorldTV

struct AboutDestinationTests {
    @Test
    func destinationsAreSecureAndValid() {
        #expect(AboutDestination.allCases.count == 4)

        for destination in AboutDestination.allCases {
            #expect(destination.url?.scheme == "https")
            #expect(destination.url?.host() != nil)
        }
    }

    @Test
    func privacyPolicyUsesThePublishedRepositoryDocument() {
        #expect(
            AboutDestination.privacy.url?.absoluteString
                == "https://hernirg.github.io/WorldTV/#privacy"
        )
    }
}
