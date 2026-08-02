import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class FavoritesStore {
    private(set) var identifiers: Set<String> = []
    private(set) var orderedIdentifiers: [String] = []
    private(set) var persistenceFailed = false

    private let loadFavorites: LoadFavoriteChannelIDsUseCase
    private let toggleFavorite: ToggleFavoriteUseCase
    private let clearFavorites: ClearFavoritesUseCase
    private let logger = Logger(subsystem: "hrgapps.WorldTV", category: "persistence")
    private var hasLoaded = false

    init(
        loadFavorites: LoadFavoriteChannelIDsUseCase,
        toggleFavorite: ToggleFavoriteUseCase,
        clearFavorites: ClearFavoritesUseCase
    ) {
        self.loadFavorites = loadFavorites
        self.toggleFavorite = toggleFavorite
        self.clearFavorites = clearFavorites
    }

    func contains(_ channelID: String) -> Bool {
        identifiers.contains(channelID)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }
        do {
            let loadedIdentifiers = try await loadFavorites.execute()
            orderedIdentifiers = loadedIdentifiers
            identifiers = Set(loadedIdentifiers)
            hasLoaded = true
            persistenceFailed = false
        } catch {
            persistenceFailed = true
            logger.error("Favorites could not be loaded")
        }
    }

    func toggle(_ channelID: String) async {
        do {
            let isFavorite = try await toggleFavorite.execute(channelID: channelID)
            if isFavorite {
                if !orderedIdentifiers.contains(channelID) {
                    orderedIdentifiers.append(channelID)
                }
                identifiers.insert(channelID)
            } else {
                orderedIdentifiers.removeAll { $0 == channelID }
                identifiers.remove(channelID)
            }
            persistenceFailed = false
            NotificationCenter.default.post(name: .topShelfDataDidChange, object: nil)
        } catch {
            persistenceFailed = true
            logger.error("Favorite could not be changed")
        }
    }

    func clear() async {
        do {
            try await clearFavorites.execute()
            identifiers.removeAll()
            orderedIdentifiers.removeAll()
            persistenceFailed = false
        } catch {
            persistenceFailed = true
            logger.error("Favorites could not be cleared")
        }
    }
}
