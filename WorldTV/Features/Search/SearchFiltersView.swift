import SwiftUI

struct SearchFiltersView: View {
    @Bindable var viewModel: SearchViewModel
    let options: ChannelSearchOptions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(tvOS)
        tvOSFilters
        #else
        NavigationStack {
            Form {
                filterControls
            }
            .platformNavigationTitle("search.filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") {
                        dismiss()
                    }
                }
            }
        }
        #endif
    }

    #if os(tvOS)
    private var tvOSFilters: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 24) {
                    Label(
                        "search.filters",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                    .font(.system(size: 46, weight: .bold))

                    Spacer()

                    Button("action.done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("search.filters.done")
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 32)
                .background(Color(white: 0.15))

                Form {
                    filterControls
                }
                .background(Color(white: 0.11))
            }
            .background(Color(white: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color(white: 0.25), lineWidth: 2)
            }
            .shadow(color: .black, radius: 50, y: 24)
            .frame(maxWidth: 1_200, maxHeight: 820)
            .padding(80)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("search.filters.panel")
        }
        .onExitCommand {
            dismiss()
        }
    }
    #endif

    @ViewBuilder
    private var filterControls: some View {
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
}
