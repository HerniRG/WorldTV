import SwiftUI

struct FavoritesView: View {
    @State private var viewModel: FavoritesViewModel
    let favoritesStore: FavoritesStore
    #if os(tvOS)
    @FocusState private var focusedChannelID: String?
    #endif

    init(
        loadFavoriteChannels: LoadFavoriteChannelsUseCase,
        favoritesStore: FavoritesStore
    ) {
        _viewModel = State(
            initialValue: FavoritesViewModel(
                loadFavoriteChannels: loadFavoriteChannels
            )
        )
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
        #if os(tvOS)
        .onChange(of: favoritesStore.orderedIdentifiers) { _, _ in
            restoreFocusIfNeeded()
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .playlistSourcesDidChange)) { _ in
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
                            favoritesStore: favoritesStore
                        )
                        #if os(tvOS)
                        .focused($focusedChannelID, equals: item.id)
                        #endif
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

    #if os(tvOS)
    private func restoreFocusIfNeeded() {
        guard
            let focusedChannelID,
            !favoritesStore.contains(focusedChannelID)
        else {
            return
        }

        let nextChannelID = favoritesStore.orderedIdentifiers.first {
            favoritesStore.contains($0)
        }

        Task { @MainActor in
            await Task.yield()
            self.focusedChannelID = nextChannelID
        }
    }
    #endif
}
