import SwiftUI

struct CountriesView: View {
    @State private var viewModel: CountriesViewModel

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
                        .worldTVCardButtonStyle()
                    }
                }
            }
            .padding(DesignTokens.pagePadding)
        }
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
