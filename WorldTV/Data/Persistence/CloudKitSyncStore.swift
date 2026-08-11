import CloudKit
import Foundation

/// Optional CloudKit replica for the small amount of user-owned app state.
/// Local persistence remains authoritative when iCloud is unavailable.
actor CloudKitSyncStore {
    private static let recordName = "worldtv.profile"
    private static let favoritesKey = "favoriteChannelIDs"
    private static let sourcesKey = "playlistSources"
    private static let historyKey = "recentlyWatched"
    private static let preferencesKey = "userPreferences"

    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: recordName)

    init(container: CKContainer = CKContainer(identifier: "iCloud.hrgapps.WorldTV")) {
        database = container.privateCloudDatabase
    }

    func load() async throws -> (favorites: [String], sources: [PlaylistSource]) {
        let record = try await database.record(for: recordID)
        return try decode(record)
    }

    func loadIfExists() async throws -> (favorites: [String], sources: [PlaylistSource])? {
        do {
            return try await load()
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func loadHistory() async throws -> [RecentlyWatchedChannel] {
        let record = try await database.record(for: recordID)
        let data = record[Self.historyKey] as? Data ?? Data()
        return data.isEmpty ? [] : try JSONDecoder().decode([RecentlyWatchedChannel].self, from: data)
    }

    func saveHistory(_ history: [RecentlyWatchedChannel]) async throws {
        let record: CKRecord
        do { record = try await database.record(for: recordID) }
        catch let error as CKError where error.code == .unknownItem { record = CKRecord(recordType: "WorldTVProfile", recordID: recordID) }
        record[Self.historyKey] = try JSONEncoder().encode(history) as NSData
        _ = try await database.save(record)
        UserDefaults.standard.set(Date(), forKey: "WorldTV.lastCloudKitSync")
    }

    struct Preferences: Codable, Equatable, Sendable {
        let autoplayChannels: Bool
        let preferredQuality: String
        let showGeoBlockedChannels: Bool
        let updatedAt: Date
    }

    func loadPreferences() async throws -> Preferences? {
        let record = try await database.record(for: recordID)
        guard let data = record[Self.preferencesKey] as? Data, !data.isEmpty else { return nil }
        return try JSONDecoder().decode(Preferences.self, from: data)
    }

    func savePreferences(_ preferences: Preferences) async throws {
        let record: CKRecord
        do { record = try await database.record(for: recordID) }
        catch let error as CKError where error.code == .unknownItem { record = CKRecord(recordType: "WorldTVProfile", recordID: recordID) }
        record[Self.preferencesKey] = try JSONEncoder().encode(preferences) as NSData
        _ = try await database.save(record)
        UserDefaults.standard.set(Date(), forKey: "WorldTV.lastCloudKitSync")
    }

    func lastSyncDate() -> Date? { UserDefaults.standard.object(forKey: "WorldTV.lastCloudKitSync") as? Date }

    func retrySync() async {
        do { _ = try await loadIfExists(); UserDefaults.standard.set(Date(), forKey: "WorldTV.lastCloudKitSync") }
        catch { }
    }

    private func decode(_ record: CKRecord) throws -> (favorites: [String], sources: [PlaylistSource]) {
        let favoriteIDs = record[Self.favoritesKey] as? [String] ?? []
        let sourcesData = record[Self.sourcesKey] as? Data ?? Data()
        let sources = sourcesData.isEmpty
            ? []
            : try JSONDecoder().decode([PlaylistSource].self, from: sourcesData)
        return (favoriteIDs, sources)
    }

    func save(favorites: [String], sources: [PlaylistSource]) async throws {
        var lastError: Error?
        for _ in 0..<3 {
            do {
                let record: CKRecord
                do {
                    record = try await database.record(for: recordID)
                } catch let error as CKError where error.code == .unknownItem {
                    record = CKRecord(recordType: "WorldTVProfile", recordID: recordID)
                }
                record[Self.favoritesKey] = favorites as NSArray
                record[Self.sourcesKey] = try JSONEncoder().encode(sources) as NSData
                _ = try await database.save(record)
                UserDefaults.standard.set(Date(), forKey: "WorldTV.lastCloudKitSync")
                print("CloudKit profile saved: favorites=\(favorites.count), sources=\(sources.count)")
                return
            } catch {
                lastError = error
                if let cloudKitError = error as? CKError,
                   cloudKitError.code != .serverRecordChanged {
                    throw error
                }
            }
        }
        if let lastError { throw lastError }
    }
}

actor SyncedFavoritesRepository: FavoritesRepository {
    private let local: UserDefaultsFavoritesRepository
    private let cloud: CloudKitSyncStore

    init(local: UserDefaultsFavoritesRepository, cloud: CloudKitSyncStore) {
        self.local = local
        self.cloud = cloud
    }

    func load() async throws -> [String] {
        let localIDs = await local.load()
        do {
            let remote = try await cloud.loadIfExists()
            if let remote {
                if remote.favorites != localIDs { await local.set(remote.favorites) }
                return remote.favorites
            }

            try await cloud.save(favorites: localIDs, sources: [])
            return localIDs
        } catch {
            print("CloudKit favorites load failed: \(error.localizedDescription)")
            return localIDs
        }
    }

    func toggle(channelID: String) async throws -> Bool {
        if let remote = try? await cloud.loadIfExists() {
            await local.set(remote.favorites)
        }
        let isFavorite = await local.toggle(channelID: channelID)
        let favorites = await local.load()
        do {
            let remote = try await cloud.loadIfExists()
            try await cloud.save(favorites: favorites, sources: remote?.sources ?? [])
        } catch {
            // Local persistence remains available when iCloud is unavailable.
            print("CloudKit favorites save failed: \(error.localizedDescription)")
        }
        return isFavorite
    }

    func clear() async throws {
        await local.clear()
        do {
            let remote = try await cloud.loadIfExists()
            try await cloud.save(favorites: [], sources: remote?.sources ?? [])
        } catch {
            // Local persistence remains available when iCloud is unavailable.
            print("CloudKit favorites clear failed: \(error.localizedDescription)")
        }
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

actor SyncedPlaylistSourceStore: PlaylistSourceStore {
    private let local: FilePlaylistSourceStore
    private let cloud: CloudKitSyncStore

    init(local: FilePlaylistSourceStore, cloud: CloudKitSyncStore) {
        self.local = local
        self.cloud = cloud
    }

    func load() async throws -> [PlaylistSource] {
        let localSources = try await local.load()
        do {
            let remote = try await cloud.loadIfExists()
            if let remote {
                if remote.sources != localSources { try await local.replace(remote.sources) }
                return remote.sources
            }

            try await cloud.save(favorites: [], sources: localSources)
            return localSources
        } catch {
            print("CloudKit sources load failed: \(error.localizedDescription)")
            return localSources
        }
    }

    func add(_ source: PlaylistSource) async throws {
        let remote: (favorites: [String], sources: [PlaylistSource])?
        do {
            remote = try await cloud.loadIfExists()
        } catch {
            remote = nil
        }
        var sources: [PlaylistSource]
        if let remoteSources = remote?.sources {
            sources = remoteSources
        } else {
            sources = try await local.load()
        }
        if !sources.contains(where: { $0.url.absoluteString.lowercased() == source.url.absoluteString.lowercased() }) {
            sources.append(source)
        }
        try await local.replace(sources)
        try? await cloud.save(favorites: remote?.favorites ?? [], sources: sources)
    }

    func remove(id: UUID) async throws {
        let remote: (favorites: [String], sources: [PlaylistSource])?
        do {
            remote = try await cloud.loadIfExists()
        } catch {
            remote = nil
        }
        let currentSources: [PlaylistSource]
        if let remoteSources = remote?.sources {
            currentSources = remoteSources
        } else {
            currentSources = try await local.load()
        }
        let sources = currentSources.filter { $0.id != id }
        try await local.replace(sources)
        try? await cloud.save(favorites: remote?.favorites ?? [], sources: sources)
    }

    func replace(_ sources: [PlaylistSource]) async throws {
        try await local.replace(sources)
        try await publishLocalState()
    }

    private func publishLocalState() async throws {
        let sources = try await local.load()
        do {
            let remote = try await cloud.loadIfExists()
            try await cloud.save(favorites: remote?.favorites ?? [], sources: sources)
        } catch {
            // Local persistence remains available when iCloud is unavailable.
            print("CloudKit sources save failed: \(error.localizedDescription)")
        }
    }

    private func merge(_ left: [PlaylistSource], _ right: [PlaylistSource]) -> [PlaylistSource] {
        var result = left
        var existingURLs = Set(left.map { $0.url.absoluteString.lowercased() })
        for source in right where existingURLs.insert(source.url.absoluteString.lowercased()).inserted {
            result.append(source)
        }
        return result
    }
}

actor SyncedRecentlyWatchedRepository: RecentlyWatchedRepository {
    private let local: UserDefaultsRecentlyWatchedRepository
    private let cloud: CloudKitSyncStore

    init(local: UserDefaultsRecentlyWatchedRepository, cloud: CloudKitSyncStore) { self.local = local; self.cloud = cloud }

    func load() async throws -> [RecentlyWatchedChannel] {
        let localValue = try await local.load()
        do {
            let remote = try await cloud.loadHistory()
            let merged = Self.merge(localValue, remote)
            if merged != localValue { try await local.replace(merged) }
            if merged != remote { try await cloud.saveHistory(merged) }
            return merged
        } catch { return localValue }
    }

    func record(channelID: String, at date: Date) async throws {
        try await local.record(channelID: channelID, at: date)
        do { try await cloud.saveHistory(Self.merge(try await local.load(), (try? await cloud.loadHistory()) ?? [])) } catch { }
    }

    func clear() async throws { await local.clear(); try? await cloud.saveHistory([]) }

    private static func merge(_ left: [RecentlyWatchedChannel], _ right: [RecentlyWatchedChannel]) -> [RecentlyWatchedChannel] {
        var byID: [String: RecentlyWatchedChannel] = [:]
        for item in left + right where byID[item.channelID] == nil || byID[item.channelID]!.watchedAt < item.watchedAt { byID[item.channelID] = item }
        return Array(byID.values.sorted { $0.watchedAt > $1.watchedAt }.prefix(20))
    }
}
