import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @AppStorage("showGeoBlockedChannels") private var showGeoBlockedChannels = true
    @AppStorage("autoplayChannels") private var autoplayChannels = true
    @AppStorage("preferredQuality") private var preferredQuality = "automatic"
    @State private var confirmation: Confirmation?
    #if os(tvOS)
    @Environment(\.resetFocus) private var resetFocus
    @Namespace private var focusNamespace
    #endif

    let favoritesStore: FavoritesStore

    init(
        refreshCatalog: RefreshCatalogUseCase,
        clearRecentlyWatched: ClearRecentlyWatchedUseCase,
        clearCatalogCache: ClearCatalogCacheUseCase,
        loadCatalogCacheDate: LoadCatalogCacheDateUseCase,
        favoritesStore: FavoritesStore,
        focusTarget: SettingsFocusTarget? = nil
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
        self.focusTarget = focusTarget
    }

    private let focusTarget: SettingsFocusTarget?

    var body: some View {
        Form {
            #if os(tvOS)
            TVScreenHeader("settings.title", systemImage: "gearshape")
                .listRowBackground(Color.clear)
            #endif

            Section("settings.section.playback") {
                Toggle("settings.autoplay", isOn: $autoplayChannels)
                #if os(tvOS)
                NavigationLink(value: AppRoute.settingsQuality) {
                    LabeledContent("settings.quality") {
                        Text(preferredQualityLabel)
                    }
                }
                #else
                Picker("settings.quality", selection: $preferredQuality) {
                    Text("settings.quality.automatic").tag("automatic")
                    Text("720p").tag("720")
                    Text("1080p").tag("1080")
                    Text("2160p").tag("2160")
                }
                #endif
                Toggle("settings.geoblocked", isOn: $showGeoBlockedChannels)
            }

            Section("settings.section.catalog") {
                NavigationLink(value: AppRoute.sources) {
                    Label("sources.manage", systemImage: "list.bullet.rectangle")
                }
                #if os(tvOS)
                .prefersDefaultFocus(
                    focusTarget == .sources,
                    in: focusNamespace
                )
                #endif
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
        #if os(tvOS)
        .focusScope(focusNamespace)
        #endif
        .platformNavigationTitle("settings.title")
        .task {
            await favoritesStore.loadIfNeeded()
            await viewModel.load()
        }
        #if os(tvOS)
        .onAppear {
            if focusTarget == .sources {
                resetFocus(in: focusNamespace)
            }
        }
        .onChange(of: focusTarget) { _, newValue in
            if newValue == .sources {
                resetFocus(in: focusNamespace)
            }
        }
        #endif
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

    #if os(tvOS)
    private var preferredQualityLabel: LocalizedStringKey {
        switch preferredQuality {
        case "720": return "720p"
        case "1080": return "1080p"
        case "2160": return "2160p"
        default: return "settings.quality.automatic"
        }
    }
    #endif

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

struct SettingsQualityView: View {
    @AppStorage("preferredQuality") private var preferredQuality = "automatic"

    private let options = [
        (id: "automatic", key: "settings.quality.automatic"),
        (id: "720", key: "720p"),
        (id: "1080", key: "1080p"),
        (id: "2160", key: "2160p")
    ]

    var body: some View {
        List {
            Section {
                ForEach(options, id: \.id) { option in
                    Button {
                        preferredQuality = option.id
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(option.key))
                            Spacer()
                            if preferredQuality == option.id {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
        }
        .platformNavigationTitle("settings.quality")
    }
}

enum SettingsFocusTarget: Hashable {
    case sources
}

private enum Confirmation {
    case favorites
    case history
    case cache
}
