import Foundation
import Observation

@Observable
@MainActor
final class CountriesViewModel {
    private(set) var state: Loadable<[CountryCatalogItem]> = .idle
    var searchText = ""

    private let loadCountries: LoadCountriesUseCase

    init(loadCountries: LoadCountriesUseCase) {
        self.loadCountries = loadCountries
    }

    var filteredCountries: [CountryCatalogItem] {
        guard case .loaded(let countries) = state else {
            return []
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return countries
        }
        return countries.filter {
            localizedName(for: $0.country).localizedCaseInsensitiveContains(query)
                || $0.country.code.localizedCaseInsensitiveContains(query)
        }
    }

    func loadIfNeeded() async {
        guard case .idle = state else {
            return
        }
        state = .loading
        do {
            let countries = try await loadCountries.execute()
            state = countries.isEmpty ? .empty : .loaded(countries)
        } catch {
            state = .failed(.catalogUnavailable)
        }
    }

    func retry() {
        state = .idle
    }

    func localizedName(for country: Country) -> String {
        Locale.current.localizedString(forRegionCode: country.code) ?? country.name
    }
}
