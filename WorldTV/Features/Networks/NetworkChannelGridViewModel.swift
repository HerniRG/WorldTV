import Foundation
import Observation

@Observable
@MainActor
final class NetworkChannelGridViewModel: LoadableViewModel<BroadcasterChannels> {
    var searchText = ""

    private let broadcasterID: String
    private let loadChannels: LoadChannelsByBroadcasterUseCase

    init(broadcasterID: String, loadChannels: LoadChannelsByBroadcasterUseCase) {
        self.broadcasterID = broadcasterID
        self.loadChannels = loadChannels
        super.init(load: { [broadcasterID, loadChannels] _ in
            try await loadChannels.execute(broadcasterID: broadcasterID)
        })
    }

    var filteredChannels: [ChannelCatalogItem] {
        guard case .loaded(let content) = state else {
            return []
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return content.channels
        }
        return content.channels.filter { item in
            item.channel.name.localizedCaseInsensitiveContains(query)
                || item.channel.alternativeNames.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        }
    }
}
