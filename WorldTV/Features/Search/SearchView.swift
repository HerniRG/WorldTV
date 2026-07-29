import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var presentsFilters = false
    @AppStorage("showGeoBlockedChannels") private var showGeoBlockedChannels = true

    let imageLoader: any ImageLoading
    let favoritesStore: FavoritesStore

    init(
        searchChannels: SearchChannelsUseCase,
        imageLoader: any ImageLoading,
        favoritesStore: FavoritesStore,
        initialCategoryID: String? = nil
    ) {
        _viewModel = State(
            initialValue: SearchViewModel(
                searchChannels: searchChannels,
                initialCategoryID: initialCategoryID
            )
        )
        self.imageLoader = imageLoader
        self.favoritesStore = favoritesStore
    }

    var body: some View {
        #if os(tvOS)
        searchContent
            .overlay(alignment: .topTrailing) {
                filtersButton
                    .buttonStyle(.borderedProminent)
                    .padding(DesignTokens.pagePadding)
            }
            .fullScreenCover(isPresented: $presentsFilters) {
                SearchFiltersView(viewModel: viewModel, options: viewModel.options)
            }
        #else
        searchContent
            .toolbar {
                ToolbarItem {
                    filtersButton
                }
            }
            .sheet(isPresented: $presentsFilters) {
                SearchFiltersView(viewModel: viewModel, options: viewModel.options)
            }
        #endif
    }

    private var searchContent: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("search.loading")
            case .loaded(let result):
                results(result.channels)
            case .empty:
                ContentUnavailableView.search(text: viewModel.query)
            case .failed:
                ContentUnavailableView {
                    Label("catalog.error.title", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("action.retry") {
                        viewModel.refresh()
                    }
                }
            }
        }
        .platformNavigationTitle("search.title")
        .searchable(text: $viewModel.query, prompt: "search.prompt")
        .task {
            await favoritesStore.loadIfNeeded()
            viewModel.includeGeoBlocked = showGeoBlockedChannels
            viewModel.loadIfNeeded()
        }
        .onChange(of: favoritesStore.orderedIdentifiers) {
            if viewModel.favoritesOnly {
                viewModel.refresh()
            }
        }
    }

    private var filtersButton: some View {
        Button {
            presentsFilters = true
        } label: {
            HStack {
                Label("search.filters", systemImage: "line.3.horizontal.decrease")
                if viewModel.activeFilterCount > 0 {
                    Text(viewModel.activeFilterCount.formatted())
                        .font(.caption.monospacedDigit())
                }
            }
        }
        .accessibilityIdentifier("search.filters.button")
    }

    private func results(_ channels: [ChannelCatalogItem]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                TVScreenHeader("search.title", systemImage: "magnifyingglass")

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: DesignTokens.channelGridMinimum),
                            spacing: DesignTokens.contentSpacing
                        )
                    ],
                    spacing: DesignTokens.contentSpacing
                ) {
                    ForEach(channels) { item in
                        ChannelTile(
                            item: item,
                            imageLoader: imageLoader,
                            favoritesStore: favoritesStore
                        )
                    }
                }
            }
            .padding(DesignTokens.pagePadding)
        }
    }
}
