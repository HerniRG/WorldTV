import Foundation

actor UserDefaultsFavoritesRepository: FavoritesRepository {
    private let suiteName: String?
    private let key: String

    init(suiteName: String? = nil, key: String = "favoriteChannelIDs") {
        self.suiteName = suiteName
        self.key = key
    }

    func load() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func toggle(channelID: String) -> Bool {
        var identifiers = load()
        if let index = identifiers.firstIndex(of: channelID) {
            identifiers.remove(at: index)
            defaults.set(identifiers, forKey: key)
            return false
        }

        identifiers.append(channelID)
        defaults.set(identifiers, forKey: key)
        return true
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    private var defaults: UserDefaults {
        if let suiteName, let defaults = UserDefaults(suiteName: suiteName) {
            return defaults
        }
        return .standard
    }
}
