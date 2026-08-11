import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class SettingsViewModel {
    private(set) var lastCatalogUpdate: Date?
    private(set) var isWorking = false
    private(set) var statusKey: String?
    private(set) var lastSyncDate: Date?
    private(set) var syncHasError = false
    private(set) var syncIsWorking = false

    private let refreshCatalog: RefreshCatalogUseCase
    private let clearRecentlyWatched: ClearRecentlyWatchedUseCase
    private let clearCatalogCache: ClearCatalogCacheUseCase
    private let loadCatalogCacheDate: LoadCatalogCacheDateUseCase
    private let logger = Logger(subsystem: "hrgapps.WorldTV", category: "persistence")
    private let cloudSyncStore: CloudKitSyncStore

    init(
        refreshCatalog: RefreshCatalogUseCase,
        clearRecentlyWatched: ClearRecentlyWatchedUseCase,
        clearCatalogCache: ClearCatalogCacheUseCase,
        loadCatalogCacheDate: LoadCatalogCacheDateUseCase,
        cloudSyncStore: CloudKitSyncStore
    ) {
        self.refreshCatalog = refreshCatalog
        self.clearRecentlyWatched = clearRecentlyWatched
        self.clearCatalogCache = clearCatalogCache
        self.loadCatalogCacheDate = loadCatalogCacheDate
        self.cloudSyncStore = cloudSyncStore
    }

    func load() async {
        do {
            lastCatalogUpdate = try await loadCatalogCacheDate.execute()
        } catch {
            logger.warning("Catalog cache date could not be read")
        }
        lastSyncDate = await cloudSyncStore.lastSyncDate()
        syncHasError = await cloudSyncStore.hasSyncError()
    }

    func retrySync() async {
        guard !syncIsWorking else { return }
        syncIsWorking = true; defer { syncIsWorking = false }
        await cloudSyncStore.retrySync()
        lastSyncDate = await cloudSyncStore.lastSyncDate()
        syncHasError = await cloudSyncStore.hasSyncError()
    }

    func savePreferences(
        autoplayChannels: Bool,
        preferredQuality: String,
        showGeoBlockedChannels: Bool
    ) async {
        let preferences = CloudKitSyncStore.Preferences(
            autoplayChannels: autoplayChannels,
            preferredQuality: preferredQuality,
            showGeoBlockedChannels: showGeoBlockedChannels,
            updatedAt: .now
        )
        do {
            try await cloudSyncStore.savePreferences(preferences)
            UserDefaults.standard.set(preferences.updatedAt, forKey: "WorldTV.preferencesUpdatedAt")
            lastSyncDate = await cloudSyncStore.lastSyncDate()
        } catch {
            logger.warning("Preferences could not be synced")
        }
    }

    func refresh() async {
        await perform(successKey: "settings.status.refreshed") {
            _ = try await refreshCatalog.execute()
            lastCatalogUpdate = try await loadCatalogCacheDate.execute()
        }
    }

    func clearHistory() async {
        await perform(successKey: "settings.status.historyCleared") {
            try await clearRecentlyWatched.execute()
        }
    }

    func clearCache() async {
        await perform(successKey: "settings.status.cacheCleared") {
            try await clearCatalogCache.execute()
            lastCatalogUpdate = nil
        }
    }

    private func perform(
        successKey: String,
        action: () async throws -> Void
    ) async {
        guard !isWorking else {
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await action()
            statusKey = successKey
        } catch {
            statusKey = "settings.status.failed"
            logger.error("Settings action failed")
        }
    }
}
