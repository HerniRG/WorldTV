import Foundation

struct Language: Identifiable, Hashable, Sendable {
    var id: String { code }

    let code: String
    let name: String
}
