import SwiftUI

struct FavoritesView: View {
    @State private var viewModel: FavoritesViewModel
    let imageLoader: any ImageLoading
    let favoritesStore: FavoritesStore

    init(
        loadFavoriteChannels: LoadFavoriteChannelsUseCase,
        imageLoader: any ImageLoading,
        favoritesStore: FavoritesStore
    ) {
        _viewModel = State(
            initialValue: FavoritesViewModel(
                loadFavoriteChannels: loadFavoriteChannels
            )
        )
        self.imageLoader = imageLoader
        self.favoritesStore = favoritesStore
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("favorites.loading")
            case .loaded(let channels):
                grid(channels.filter { favoritesStore.contains($0.id) })
            case .empty:
                ContentUnavailableView(
                    "favorites.empty.title",
                    systemImage: "star.slash",
                    description: Text("favorites.empty.message")
                )
            case .failed:
                ContentUnavailableView {
                    Label("catalog.error.title", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("action.retry") {
                        viewModel.reload()
                    }
                }
            }
        }
        .accessibilityIdentifier("favorites.screen")
        .platformNavigationTitle("favorites.title")
        .task {
            await favoritesStore.loadIfNeeded()
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            viewModel.reload()
        }
    }

    private func grid(_ channels: [ChannelCatalogItem]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                TVScreenHeader("favorites.title", systemImage: "star.fill")

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
                #if os(tvOS)
                .focusSection()
                #endif
            }
            .padding(DesignTokens.pagePadding)
        }
        .overlay {
            if channels.isEmpty {
                ContentUnavailableView(
                    "favorites.empty.title",
                    systemImage: "star.slash",
                    description: Text("favorites.empty.message")
                )
            }
        }
    }
}
