import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @AppStorage("showGeoBlockedChannels") private var showGeoBlockedChannels = true
    @AppStorage("autoplayChannels") private var autoplayChannels = true
    @AppStorage("preferredQuality") private var preferredQuality = "automatic"
    @State private var confirmation: Confirmation?

    let favoritesStore: FavoritesStore
    let loadPlaylistSources: LoadPlaylistSourcesUseCase
    let addPlaylistSource: AddPlaylistSourceUseCase
    let removePlaylistSource: RemovePlaylistSourceUseCase

    init(
        refreshCatalog: RefreshCatalogUseCase,
        clearRecentlyWatched: ClearRecentlyWatchedUseCase,
        clearCatalogCache: ClearCatalogCacheUseCase,
        loadCatalogCacheDate: LoadCatalogCacheDateUseCase,
        loadPlaylistSources: LoadPlaylistSourcesUseCase,
        addPlaylistSource: AddPlaylistSourceUseCase,
        removePlaylistSource: RemovePlaylistSourceUseCase,
        favoritesStore: FavoritesStore
    ) {
        _viewModel = State(
            initialValue: SettingsViewModel(
                refreshCatalog: refreshCatalog,
                clearRecentlyWatched: clearRecentlyWatched,
                clearCatalogCache: clearCatalogCache,
                loadCatalogCacheDate: loadCatalogCacheDate
            )
        )
        self.favoritesStore = favoritesStore
        self.loadPlaylistSources = loadPlaylistSources
        self.addPlaylistSource = addPlaylistSource
        self.removePlaylistSource = removePlaylistSource
    }

    var body: some View {
        Form {
            #if os(tvOS)
            TVScreenHeader("settings.title", systemImage: "gearshape")
                .listRowBackground(Color.clear)
            #endif

            Section("settings.section.playback") {
                Toggle("settings.autoplay", isOn: $autoplayChannels)
                Picker("settings.quality", selection: $preferredQuality) {
                    Text("settings.quality.automatic").tag("automatic")
                    Text("720p").tag("720")
                    Text("1080p").tag("1080")
                    Text("2160p").tag("2160")
                }
                Toggle("settings.geoblocked", isOn: $showGeoBlockedChannels)
            }

            Section("settings.section.catalog") {
                NavigationLink {
                    PlaylistSourcesView(
                        loadSources: loadPlaylistSources,
                        addSource: addPlaylistSource,
                        removeSource: removePlaylistSource
                    )
                } label: {
                    Label("sources.manage", systemImage: "list.bullet.rectangle")
                }
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("catalog.refresh", systemImage: "arrow.clockwise")
                }
                if let date = viewModel.lastCatalogUpdate {
                    LabeledContent("settings.lastUpdate") {
                        Text(date, format: .dateTime.day().month().year().hour().minute())
                    }
                } else {
                    LabeledContent("settings.lastUpdate", value: String(localized: "settings.never"))
                }
                Button("settings.clearCache", role: .destructive) {
                    confirmation = .cache
                }
            }

            Section("settings.section.data") {
                Button("settings.clearFavorites", role: .destructive) {
                    confirmation = .favorites
                }
                Button("settings.clearHistory", role: .destructive) {
                    confirmation = .history
                }
            }

            Section {
                NavigationLink(value: AppRoute.about) {
                    Label("settings.about", systemImage: "info.circle")
                }
            }

            if viewModel.isWorking {
                ProgressView()
            }
            if let statusKey = viewModel.statusKey {
                Text(LocalizedStringKey(statusKey))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .platformNavigationTitle("settings.title")
        .task {
            await favoritesStore.loadIfNeeded()
            await viewModel.load()
        }
        .confirmationDialog(
            "settings.confirm.title",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("settings.confirm.delete", role: .destructive) {
                performConfirmation()
            }
            Button("action.cancel", role: .cancel) {
                confirmation = nil
            }
        }
    }

    private func performConfirmation() {
        let action = confirmation
        confirmation = nil
        Task {
            switch action {
            case .favorites:
                await favoritesStore.clear()
            case .history:
                await viewModel.clearHistory()
            case .cache:
                await viewModel.clearCache()
            case nil:
                break
            }
        }
    }
}

private enum Confirmation {
    case favorites
    case history
    case cache
}
