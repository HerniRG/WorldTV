import Foundation
import Observation

@Observable
@MainActor
final class ChannelGridViewModel {
    private(set) var state: Loadable<CountryChannels> = .idle
    var searchText = ""

    private let countryCode: String
    private let loadChannels: LoadChannelsByCountryUseCase

    init(countryCode: String, loadChannels: LoadChannelsByCountryUseCase) {
        self.countryCode = countryCode
        self.loadChannels = loadChannels
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

    func loadIfNeeded() async {
        guard case .idle = state else {
            return
        }
        state = .loading
        do {
            guard let content = try await loadChannels.execute(countryCode: countryCode) else {
                state = .empty
                return
            }
            state = content.channels.isEmpty ? .empty : .loaded(content)
        } catch {
            state = .failed(.catalogUnavailable)
        }
    }

    func retry() {
        state = .idle
    }
}
