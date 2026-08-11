import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    private(set) var state: Loadable<ChannelSearchResult> = .idle
    private(set) var options = ChannelSearchOptions(countries: [], categories: [])
    var query = "" {
        didSet { scheduleSearch() }
    }
    var selectedCountryCode: String? {
        didSet { persist(selectedCountryCode, key: "WorldTV.search.country"); scheduleSearch() }
    }
    var selectedCategoryID: String? {
        didSet { persist(selectedCategoryID, key: "WorldTV.search.category"); scheduleSearch() }
    }
    var selectedLanguageCode: String? {
        didSet { persist(selectedLanguageCode, key: "WorldTV.search.language"); scheduleSearch() }
    }
    var minimumQuality: Int? {
        didSet {
            if let minimumQuality {
                UserDefaults.standard.set(minimumQuality, forKey: "WorldTV.search.quality")
            } else {
                UserDefaults.standard.removeObject(forKey: "WorldTV.search.quality")
            }
            scheduleSearch()
        }
    }
    var favoritesOnly = false {
        didSet { UserDefaults.standard.set(favoritesOnly, forKey: "WorldTV.search.favoritesOnly"); scheduleSearch() }
    }
    var availableOnly = true {
        didSet { UserDefaults.standard.set(availableOnly, forKey: "WorldTV.search.availableOnly"); scheduleSearch() }
    }
    var includeGeoBlocked = true {
        didSet { UserDefaults.standard.set(includeGeoBlocked, forKey: "WorldTV.search.includeGeoBlocked"); scheduleSearch() }
    }

    private let searchChannels: SearchChannelsUseCase
    private var searchTask: Task<Void, Never>?
    private var hasLoaded = false

    init(
        searchChannels: SearchChannelsUseCase,
        initialCategoryID: String? = nil,
        initialCountryCode: String? = nil
    ) {
        self.searchChannels = searchChannels
        let defaults = UserDefaults.standard
        selectedCategoryID = initialCategoryID ?? defaults.string(forKey: "WorldTV.search.category")
        selectedCountryCode = initialCountryCode ?? defaults.string(forKey: "WorldTV.search.country")
        selectedLanguageCode = defaults.string(forKey: "WorldTV.search.language")
        minimumQuality = defaults.object(forKey: "WorldTV.search.quality") as? Int
        favoritesOnly = defaults.object(forKey: "WorldTV.search.favoritesOnly") as? Bool ?? false
        availableOnly = defaults.object(forKey: "WorldTV.search.availableOnly") as? Bool ?? true
        includeGeoBlocked = defaults.object(forKey: "WorldTV.search.includeGeoBlocked") as? Bool ?? true
    }

    var activeFilterCount: Int {
        [
            selectedCountryCode != nil,
            selectedCategoryID != nil,
            selectedLanguageCode != nil,
            minimumQuality != nil,
            favoritesOnly,
            !availableOnly,
            !includeGeoBlocked
        ]
        .filter { $0 }
        .count
    }

    func loadIfNeeded() {
        guard !hasLoaded else {
            return
        }
        hasLoaded = true
        search(immediately: true)
    }

    func refresh() {
        search(immediately: true)
    }

    func resetFilters() {
        selectedCountryCode = nil
        selectedCategoryID = nil
        selectedLanguageCode = nil
        minimumQuality = nil
        favoritesOnly = false
        availableOnly = true
        includeGeoBlocked = true
        search(immediately: true)
    }

    func applyTopLevelFilter(categoryID: String?, countryCode: String?) {
        guard
            selectedCategoryID != categoryID
                || selectedCountryCode != countryCode
        else {
            return
        }

        selectedCategoryID = categoryID
        selectedCountryCode = countryCode
        search(immediately: true)
    }

    private var criteria: ChannelSearchCriteria {
        ChannelSearchCriteria(
            query: query,
            countryCode: selectedCountryCode,
            categoryID: selectedCategoryID,
            languageCode: selectedLanguageCode,
            minimumQuality: minimumQuality,
            favoritesOnly: favoritesOnly,
            availableOnly: availableOnly,
            includeGeoBlocked: includeGeoBlocked
        )
    }

    private func scheduleSearch() {
        guard hasLoaded else {
            return
        }
        search(immediately: false)
    }

    private func search(immediately: Bool) {
        searchTask?.cancel()
        let criteria = criteria
        searchTask = Task { [weak self] in
            if !immediately {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                } catch {
                    return
                }
            }
            guard let self, !Task.isCancelled else {
                return
            }
            do {
                let result = try await searchChannels.execute(criteria: criteria)
                guard !Task.isCancelled else {
                    return
                }
                options = result.options
                state = result.channels.isEmpty ? .empty : .loaded(result)
            } catch is CancellationError {
                return
            } catch {
                state = .failed(.catalogUnavailable)
            }
        }
    }

    private func persist(_ value: String?, key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
