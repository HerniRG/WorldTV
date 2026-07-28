import Foundation

struct Country: Identifiable, Hashable, Sendable {
    var id: String { code }

    let code: String
    let name: String
    let languageCodes: [String]
    let flag: String?
}
