import Foundation
import Observation

@Observable
@MainActor
final class CountriesViewModel: LoadableViewModel<[CountryCatalogItem]> {
    var searchText = ""

    private let loadCountries: LoadCountriesUseCase

    init(loadCountries: LoadCountriesUseCase) {
        self.loadCountries = loadCountries
        super.init(load: { [loadCountries] _ in
            let countries = try await loadCountries.execute()
            return countries.isEmpty ? nil : countries
        })
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

    func localizedName(for country: Country) -> String {
        Locale.current.localizedString(forRegionCode: country.code) ?? country.name
    }
}
