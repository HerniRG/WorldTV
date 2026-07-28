import Foundation

actor UserDefaultsRecentlyWatchedRepository: RecentlyWatchedRepository {
    private let suiteName: String?
    private let key: String
    private let maximumCount: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        suiteName: String? = nil,
        key: String = "recentlyWatched",
        maximumCount: Int = 20
    ) {
        self.suiteName = suiteName
        self.key = key
        self.maximumCount = maximumCount
    }

    func load() throws -> [RecentlyWatchedChannel] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }
        return try decoder.decode([RecentlyWatchedChannel].self, from: data)
    }

    func record(channelID: String, at date: Date) throws {
        var items = try load()
        items.removeAll { $0.channelID == channelID }
        items.insert(RecentlyWatchedChannel(channelID: channelID, watchedAt: date), at: 0)
        if items.count > maximumCount {
            items.removeLast(items.count - maximumCount)
        }
        defaults.set(try encoder.encode(items), forKey: key)
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
