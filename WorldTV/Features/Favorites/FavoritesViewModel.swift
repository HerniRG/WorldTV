import Foundation
import Observation

@Observable
@MainActor
final class FavoritesViewModel {
    private(set) var state: Loadable<[ChannelCatalogItem]> = .idle

    private let loadFavoriteChannels: LoadFavoriteChannelsUseCase

    init(loadFavoriteChannels: LoadFavoriteChannelsUseCase) {
        self.loadFavoriteChannels = loadFavoriteChannels
    }

    func loadIfNeeded() async {
        guard case .idle = state else {
            return
        }
        await load()
    }

    func reload() {
        Task {
            await load()
        }
    }

    private func load() async {
        state = .loading
        do {
            let channels = try await loadFavoriteChannels.execute()
            state = channels.isEmpty ? .empty : .loaded(channels)
        } catch {
            state = .failed(.catalogUnavailable)
        }
    }
}
