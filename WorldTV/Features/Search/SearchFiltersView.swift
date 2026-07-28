import SwiftUI

struct SearchFiltersView: View {
    @Bindable var viewModel: SearchViewModel
    let options: ChannelSearchOptions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("search.filter.country", selection: $viewModel.selectedCountryCode) {
                    Text("search.filter.any").tag(String?.none)
                    ForEach(options.countries) { country in
                        Text(
                            Locale.current.localizedString(forRegionCode: country.code)
                                ?? country.name
                        )
                        .tag(Optional(country.code))
                    }
                }

                Picker("search.filter.category", selection: $viewModel.selectedCategoryID) {
                    Text("search.filter.any").tag(String?.none)
                    ForEach(options.categories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }

                Picker("search.filter.quality", selection: $viewModel.minimumQuality) {
                    Text("search.filter.any").tag(Int?.none)
                    Text("720p").tag(Optional(720))
                    Text("1080p").tag(Optional(1080))
                    Text("2160p").tag(Optional(2160))
                }

                Toggle("search.filter.favorites", isOn: $viewModel.favoritesOnly)
                Toggle("search.filter.available", isOn: $viewModel.availableOnly)
                Toggle("search.filter.geoblocked", isOn: $viewModel.includeGeoBlocked)

                Button("search.filter.reset", role: .destructive) {
                    viewModel.resetFilters()
                }
            }
            .navigationTitle("search.filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
