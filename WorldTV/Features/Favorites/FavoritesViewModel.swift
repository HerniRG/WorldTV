import Foundation
import Observation

@Observable
@MainActor
final class FavoritesViewModel: LoadableViewModel<[ChannelCatalogItem]> {
    private let loadFavoriteChannels: LoadFavoriteChannelsUseCase

    init(loadFavoriteChannels: LoadFavoriteChannelsUseCase) {
        self.loadFavoriteChannels = loadFavoriteChannels
        super.init(load: { [loadFavoriteChannels] _ in
            let channels = try await loadFavoriteChannels.execute()
            return channels.isEmpty ? nil : channels
        })
    }

    func reload() {
        Task {
            await super.reload()
        }
    }
}
