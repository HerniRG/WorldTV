import Foundation
import Observation

@Observable
@MainActor
final class CategoryGridViewModel: LoadableViewModel<CategoryChannels> {
    var searchText = ""

    private let categoryID: String
    private let loadChannels: LoadChannelsByCategoryUseCase

    init(categoryID: String, loadChannels: LoadChannelsByCategoryUseCase) {
        self.categoryID = categoryID
        self.loadChannels = loadChannels
        super.init(load: { [categoryID, loadChannels] _ in
            guard let content = try await loadChannels.execute(categoryID: categoryID) else {
                return nil
            }
            return content.channels.isEmpty ? nil : content
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
