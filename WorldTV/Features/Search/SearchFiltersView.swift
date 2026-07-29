import SwiftUI

struct SearchFiltersView: View {
    @Bindable var viewModel: SearchViewModel
    let options: ChannelSearchOptions
    @Environment(\.dismiss) private var dismiss
    #if os(tvOS)
    @State private var path = NavigationPath()
    #endif

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
            Color.clear
                .ignoresSafeArea()

            NavigationStack(path: $path) {
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
                    .background(
                        Color(white: 0.15),
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: 34,
                            topTrailingRadius: 34
                        )
                    )

                    Form {
                        tvOSFilterControls
                    }
                    .padding(.horizontal, 64)
                    .padding(.vertical, 20)
                    .background(Color(white: 0.11))
                }
            }
            .contentMargins(.horizontal, 64, for: .scrollContent)
            .background(
                Color(white: 0.11),
                in: RoundedRectangle(cornerRadius: 34, style: .continuous)
            )
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
            if path.isEmpty {
                dismiss()
            } else {
                path.removeLast()
            }
        }
    }
    #endif

    #if os(tvOS)
    @ViewBuilder
    private var tvOSFilterControls: some View {
        NavigationLink {
            TVFilterSelectionView(
                title: "search.filter.country",
                selection: $viewModel.selectedCountryCode,
                options: countryOptions
            )
        } label: {
            LabeledContent("search.filter.country") {
                Text(selectedCountryName)
            }
        }
        .accessibilityIdentifier("search.filter.country")

        NavigationLink {
            TVFilterSelectionView(
                title: "search.filter.category",
                selection: $viewModel.selectedCategoryID,
                options: categoryOptions
            )
        } label: {
            LabeledContent("search.filter.category") {
                Text(selectedCategoryName)
            }
        }
        .accessibilityIdentifier("search.filter.category")

        NavigationLink {
            TVFilterSelectionView(
                title: "search.filter.quality",
                selection: $viewModel.minimumQuality,
                options: qualityOptions
            )
        } label: {
            LabeledContent("search.filter.quality") {
                Text(selectedQualityName)
            }
        }
        .accessibilityIdentifier("search.filter.quality")

        commonFilterControls
    }

    private var countryOptions: [TVFilterOption<String?>] {
        [
            TVFilterOption(
                id: "any",
                title: String(localized: "search.filter.any"),
                value: nil
            )
        ] + options.countries.map { country in
            TVFilterOption(
                id: country.code,
                title: Locale.current.localizedString(forRegionCode: country.code)
                    ?? country.name,
                value: country.code
            )
        }
    }

    private var categoryOptions: [TVFilterOption<String?>] {
        [
            TVFilterOption(
                id: "any",
                title: String(localized: "search.filter.any"),
                value: nil
            )
        ] + options.categories.map { category in
            TVFilterOption(
                id: category.id,
                title: category.name,
                value: category.id
            )
        }
    }

    private var qualityOptions: [TVFilterOption<Int?>] {
        [
            TVFilterOption(
                id: "any",
                title: String(localized: "search.filter.any"),
                value: nil
            ),
            TVFilterOption(id: "720", title: "720p", value: 720),
            TVFilterOption(id: "1080", title: "1080p", value: 1080),
            TVFilterOption(id: "2160", title: "2160p", value: 2160)
        ]
    }

    private var selectedCountryName: String {
        guard let code = viewModel.selectedCountryCode else {
            return String(localized: "search.filter.any")
        }
        return Locale.current.localizedString(forRegionCode: code)
            ?? options.countries.first(where: { $0.code == code })?.name
            ?? code
    }

    private var selectedCategoryName: String {
        guard let id = viewModel.selectedCategoryID else {
            return String(localized: "search.filter.any")
        }
        return options.categories.first(where: { $0.id == id })?.name ?? id
    }

    private var selectedQualityName: String {
        guard let quality = viewModel.minimumQuality else {
            return String(localized: "search.filter.any")
        }
        return "\(quality)p"
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

        commonFilterControls
    }

    @ViewBuilder
    private var commonFilterControls: some View {
        Toggle("search.filter.favorites", isOn: $viewModel.favoritesOnly)
        Toggle("search.filter.available", isOn: $viewModel.availableOnly)
        Toggle("search.filter.geoblocked", isOn: $viewModel.includeGeoBlocked)

        Button("search.filter.reset", role: .destructive) {
            viewModel.resetFilters()
        }
    }
}

#if os(tvOS)
private struct TVFilterOption<Value: Hashable>: Identifiable {
    let id: String
    let title: String
    let value: Value
}

private struct TVFilterSelectionView<Value: Hashable>: View {
    let title: LocalizedStringKey
    @Binding var selection: Value
    let options: [TVFilterOption<Value>]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Label(title, systemImage: "line.3.horizontal.decrease.circle")
                .font(.system(size: 46, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 48)
                .padding(.vertical, 32)
                .background(
                    Color(white: 0.15),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 34,
                        topTrailingRadius: 34
                    )
                )

            List(options) { option in
                Button {
                    selection = option.value
                    dismiss()
                } label: {
                    HStack {
                        Text(option.title)

                        Spacer()

                        if selection == option.value {
                            Image(systemName: "checkmark")
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("search.filter.option.\(option.id)")
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 20)
        }
        .background(
            Color(white: 0.11),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
    }
}
#endif
