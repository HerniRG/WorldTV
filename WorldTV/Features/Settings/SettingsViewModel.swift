import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class SettingsViewModel {
    private(set) var lastCatalogUpdate: Date?
    private(set) var isWorking = false
    private(set) var statusKey: String?

    private let refreshCatalog: RefreshCatalogUseCase
    private let clearRecentlyWatched: ClearRecentlyWatchedUseCase
    private let clearCatalogCache: ClearCatalogCacheUseCase
    private let loadCatalogCacheDate: LoadCatalogCacheDateUseCase
    private let logger = Logger(subsystem: "hrgapps.WorldTV", category: "persistence")

    init(
        refreshCatalog: RefreshCatalogUseCase,
        clearRecentlyWatched: ClearRecentlyWatchedUseCase,
        clearCatalogCache: ClearCatalogCacheUseCase,
        loadCatalogCacheDate: LoadCatalogCacheDateUseCase
    ) {
        self.refreshCatalog = refreshCatalog
        self.clearRecentlyWatched = clearRecentlyWatched
        self.clearCatalogCache = clearCatalogCache
        self.loadCatalogCacheDate = loadCatalogCacheDate
    }

    func load() async {
        do {
            lastCatalogUpdate = try await loadCatalogCacheDate.execute()
        } catch {
            logger.warning("Catalog cache date could not be read")
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
