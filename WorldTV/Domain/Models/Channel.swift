import Foundation

struct Channel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let alternativeNames: [String]
    let countryCode: String
    let categoryIDs: [String]
    let isNSFW: Bool
}
