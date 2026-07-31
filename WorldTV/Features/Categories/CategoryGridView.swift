import SwiftUI

struct CategoryGridView: View {
    @State private var viewModel: CategoryGridViewModel
    private let favoritesStore: FavoritesStore

    init(
        categoryID: String,
        loadChannels: LoadChannelsByCategoryUseCase,
        favoritesStore: FavoritesStore
    ) {
        _viewModel = State(
            initialValue: CategoryGridViewModel(
                categoryID: categoryID,
                loadChannels: loadChannels
            )
        )
        self.favoritesStore = favoritesStore
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("catalog.loading")
            case .loaded(let content):
                channelGrid(title: content.category.name)
            case .empty:
                ContentUnavailableView("channels.empty", systemImage: "tv.slash")
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
        .searchable(text: $viewModel.searchText, prompt: "channels.search")
        .task(id: stateIsIdle) {
            await viewModel.loadIfNeeded()
        }
    }

    private var stateIsIdle: Bool {
        if case .idle = viewModel.state {
            return true
        }
        return false
    }

    private func channelGrid(title: String) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                TVScreenHeader(verbatim: title, systemImage: "square.grid.2x2")

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: DesignTokens.channelGridMinimum),
                            spacing: DesignTokens.contentSpacing
                        )
                    ],
                    spacing: DesignTokens.contentSpacing
                ) {
                    ForEach(viewModel.filteredChannels) { item in
                        ChannelTile(
                            item: item,
                            favoritesStore: favoritesStore
                        )
                    }
                }
                #if os(tvOS)
                .focusSection()
                #endif
            }
            .padding(DesignTokens.pagePadding)
        }
        .platformNavigationTitle(verbatim: title)
        .overlay {
            if viewModel.filteredChannels.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }
}
