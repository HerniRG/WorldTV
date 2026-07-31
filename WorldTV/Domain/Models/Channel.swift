import Foundation

struct Channel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let alternativeNames: [String]
    let countryCode: String
    let categoryIDs: [String]
    let isNSFW: Bool
    var network: String? = nil
    var owners: [String] = []

    var broadcasterName: String {
        if let network, !network.isEmpty {
            return network
        }
        if owners.isEmpty {
            return ""
        }
        return owners.joined(separator: " + ")
    }
}
