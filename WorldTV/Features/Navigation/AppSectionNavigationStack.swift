import SwiftUI

struct AppSectionNavigationStack: View {
    @State private var path: [AppRoute] = []
    @State private var countryFocusReturn = CountryFocusReturn()

    let section: AppSection
    let homeViewModel: HomeViewModel
    let container: AppContainer
    var tvSearchRequest: TVSearchRequest?
    var tvFocusSourcesRequest = 0
    var tvNavigationResetRequest = 0
    var tvOpenTopLevelDestination: @MainActor (TVTopLevelDestination) -> Void = { _ in }

    var body: some View {
        #if os(tvOS)
        navigationStack
            .environment(
                \.playerServices,
                PlayerServices(
                    resolveSources: container.resolvePlaybackSources,
                    recordRecentlyWatched: container.recordRecentlyWatched
                )
            )
            .id(tvNavigationResetRequest)
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
        .environment(\.openTVTopLevelDestination, tvOpenTopLevelDestination)
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
                favoritesStore: container.favoritesStore
            )
        case .countries:
            CountriesView(loadCountries: container.loadCountries)
        case .search:
            SearchView(
                searchChannels: container.searchChannels,
                favoritesStore: container.favoritesStore,
                initialCategoryID: tvSearchRequest?.categoryID,
                initialCountryCode: tvSearchRequest?.countryCode
            )
            .id(tvSearchRequest?.id)
        case .favorites:
            FavoritesView(
                loadFavoriteChannels: container.loadFavoriteChannels,
                favoritesStore: container.favoritesStore
            )
        case .settings:
            SettingsView(
                refreshCatalog: container.refreshCatalog,
                clearRecentlyWatched: container.clearRecentlyWatched,
                clearCatalogCache: container.clearCatalogCache,
                loadCatalogCacheDate: container.loadCatalogCacheDate,
                loadPlaylistSources: container.loadPlaylistSources,
                addPlaylistSource: container.addPlaylistSource,
                removePlaylistSource: container.removePlaylistSource,
                favoritesStore: container.favoritesStore,
                focusSourcesRequest: tvFocusSourcesRequest
            )
            #if os(tvOS)
            .id(tvFocusSourcesRequest)
            #endif
        }
    }
}
