import SwiftUI

struct CountriesView: View {
    @State private var viewModel: CountriesViewModel
    #if os(tvOS)
    @Environment(\.countryFocusReturn) private var countryFocusReturn
    @FocusState private var focusedCountryCode: String?
    #endif

    init(loadCountries: LoadCountriesUseCase) {
        _viewModel = State(initialValue: CountriesViewModel(loadCountries: loadCountries))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("catalog.loading")
            case .loaded:
                countryGrid
            case .empty:
                ContentUnavailableView("countries.empty", systemImage: "flag.slash")
            case .failed:
                ContentUnavailableView {
                    Label("catalog.error.title", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("action.retry") {
                        viewModel.retry()
                    }
                }
            }
        }
        .platformNavigationTitle("countries.title")
        .searchable(text: $viewModel.searchText, prompt: "countries.search")
        .task(id: viewModel.state.isIdle) {
            await viewModel.loadIfNeeded()
        }
    }

    private var countryGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                TVScreenHeader("countries.title", systemImage: "flag")

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: DesignTokens.countryGridMinimum),
                            spacing: DesignTokens.contentSpacing
                        )
                    ],
                    spacing: DesignTokens.contentSpacing
                ) {
                    ForEach(viewModel.filteredCountries) { item in
                        NavigationLink(value: AppRoute.country(item.country.code)) {
                            CountryCard(item: item)
                        }
                        #if os(tvOS)
                        .focused(
                            $focusedCountryCode,
                            equals: item.country.code
                        )
                        #endif
                        .worldTVCardButtonStyle()
                        .accessibilityIdentifier("country.\(item.country.code)")
                    }
                }
                #if os(tvOS)
                .focusSection()
                #endif
            }
            .padding(DesignTokens.pagePadding)
        }
        #if os(tvOS)
        .onChange(of: countryFocusReturn) {
            guard let code = countryFocusReturn.code else {
                return
            }
            Task { @MainActor in
                focusedCountryCode = nil
                try? await Task.sleep(for: .milliseconds(300))
                focusedCountryCode = code
            }
        }
        #endif
        .overlay {
            if viewModel.filteredCountries.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }
}

private extension Loadable {
    var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }
}
