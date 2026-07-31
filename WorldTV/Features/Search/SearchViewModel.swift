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
        didSet { scheduleSearch() }
    }
    var selectedCategoryID: String? {
        didSet { scheduleSearch() }
    }
    var selectedLanguageCode: String? {
        didSet { scheduleSearch() }
    }
    var minimumQuality: Int? {
        didSet { scheduleSearch() }
    }
    var favoritesOnly = false {
        didSet { scheduleSearch() }
    }
    var availableOnly = true {
        didSet { scheduleSearch() }
    }
    var includeGeoBlocked = true {
        didSet { scheduleSearch() }
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
        selectedCategoryID = initialCategoryID
        selectedCountryCode = initialCountryCode
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
}
