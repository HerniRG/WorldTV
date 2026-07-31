import Foundation
import Observation

@Observable
@MainActor
final class ChannelGridViewModel: LoadableViewModel<CountryChannels> {
    var searchText = ""

    private let countryCode: String
    private let loadChannels: LoadChannelsByCountryUseCase

    init(countryCode: String, loadChannels: LoadChannelsByCountryUseCase) {
        self.countryCode = countryCode
        self.loadChannels = loadChannels
        super.init(load: { [countryCode, loadChannels] _ in
            guard let content = try await loadChannels.execute(countryCode: countryCode) else {
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
