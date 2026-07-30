import SwiftUI

struct AppSectionNavigationStack: View {
    #if os(macOS)
    @State private var presentsPlayer = false
    @State private var pendingChannelID: String?
    #endif
    @State private var path: [AppRoute] = []
    @State private var countryFocusReturn = CountryFocusReturn()

    let section: AppSection
    let homeViewModel: HomeViewModel
    let container: AppContainer
    var tvSearchRequest: TVSearchRequest?
    var tvOpenTopLevelDestination: @MainActor (TVTopLevelDestination) -> Void = { _ in }

    var body: some View {
        #if os(macOS)
        navigationStack
            .environment(\.playChannel) { channelID in
                pendingChannelID = channelID
                presentsPlayer = true
            }
            .sheet(isPresented: $presentsPlayer) {
                if let channelID = pendingChannelID {
                    PlayerView(
                        channelID: channelID,
                        resolveSources: container.resolvePlaybackSources,
                        recordRecentlyWatched: container.recordRecentlyWatched,
                        closePresentation: {
                            presentsPlayer = false
                        }
                    )
                    .frame(minWidth: 900, minHeight: 600)
                }
            }
        #elseif os(tvOS)
        navigationStack
            .environment(
                \.playerServices,
                PlayerServices(
                    resolveSources: container.resolvePlaybackSources,
                    recordRecentlyWatched: container.recordRecentlyWatched
                )
            )
        #else
        navigationStack
        #endif
    }

    private var navigationStack: some View {
        NavigationStack(path: $path) {
            sectionRoot
                .modifier(AppRouteDestinationModifier(container: container))
        }
        .environment(\.countryFocusReturn, countryFocusReturn)
        .onChange(of: path) { oldPath, newPath in
            guard
                newPath.count < oldPath.count,
                case .country(let code) = oldPath.last
            else {
                return
            }
            countryFocusReturn = CountryFocusReturn(
                code: code,
                generation: countryFocusReturn.generation + 1
            )
        }
    }

    @ViewBuilder
    private var sectionRoot: some View {
        switch section {
        case .home:
            HomeView(
                viewModel: homeViewModel,
                imageLoader: container.imageLoader,
                favoritesStore: container.favoritesStore,
                openTVTopLevelDestination: tvOpenTopLevelDestination
            )
        case .countries:
            CountriesView(loadCountries: container.loadCountries)
        case .search:
            SearchView(
                searchChannels: container.searchChannels,
                imageLoader: container.imageLoader,
                favoritesStore: container.favoritesStore,
                initialCategoryID: tvSearchRequest?.categoryID,
                initialCountryCode: tvSearchRequest?.countryCode
            )
            .id(tvSearchRequest?.id)
        case .favorites:
            FavoritesView(
                loadFavoriteChannels: container.loadFavoriteChannels,
                imageLoader: container.imageLoader,
                favoritesStore: container.favoritesStore
            )
        case .settings:
            SettingsView(
                refreshCatalog: container.refreshCatalog,
                clearRecentlyWatched: container.clearRecentlyWatched,
                clearCatalogCache: container.clearCatalogCache,
                loadCatalogCacheDate: container.loadCatalogCacheDate,
                favoritesStore: container.favoritesStore
            )
        }
    }
}

struct PlayerServices: Sendable {
    let resolveSources: ResolvePlayableStreamUseCase
    let recordRecentlyWatched: RecordRecentlyWatchedUseCase
}

struct CountryFocusReturn: Equatable {
    var code: String?
    var generation = 0
}

private struct PlayerServicesKey: EnvironmentKey {
    static let defaultValue: PlayerServices? = nil
}

private struct CountryFocusReturnKey: EnvironmentKey {
    static let defaultValue = CountryFocusReturn()
}

extension EnvironmentValues {
    var playerServices: PlayerServices? {
        get { self[PlayerServicesKey.self] }
        set { self[PlayerServicesKey.self] = newValue }
    }

    var countryFocusReturn: CountryFocusReturn {
        get { self[CountryFocusReturnKey.self] }
        set { self[CountryFocusReturnKey.self] = newValue }
    }
}

struct AppSidebar: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(AppSection.allCases, selection: $selection) { section in
            Label(
                LocalizedStringKey(section.localizationKey),
                systemImage: section.systemImage
            )
                .tag(section)
        }
        .navigationTitle("app.name")
    }
}

private struct AppRouteDestinationModifier: ViewModifier {
    let container: AppContainer

    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { route in
            destination(for: route)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .countries:
            CountriesView(loadCountries: container.loadCountries)
        case .favorites:
            FavoritesView(
                loadFavoriteChannels: container.loadFavoriteChannels,
                imageLoader: container.imageLoader,
                favoritesStore: container.favoritesStore
            )
        case .search:
            SearchView(
                searchChannels: container.searchChannels,
                imageLoader: container.imageLoader,
                favoritesStore: container.favoritesStore
            )
        case .searchCategory(let categoryID):
            SearchView(
                searchChannels: container.searchChannels,
                imageLoader: container.imageLoader,
                favoritesStore: container.favoritesStore,
                initialCategoryID: categoryID
            )
        case .about:
            AboutView()
        case .country(let code):
            ChannelGridView(
                countryCode: code,
                loadChannels: container.loadChannelsByCountry,
                imageLoader: container.imageLoader,
                favoritesStore: container.favoritesStore
            )
        }
    }
}
