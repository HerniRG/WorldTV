import SwiftUI

struct AppSectionNavigationStack: View {
    @Binding var path: [AppRoute]
    @State private var countryFocusReturn = CountryFocusReturn()

    let section: AppSection
    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
        navigationStack
    }

    private var navigationStack: some View {
        NavigationStack(path: $path) {
            AppSectionContent(
                section: section,
                homeViewModel: homeViewModel,
                container: container,
                countryFocusReturn: countryFocusReturn
            )
            .modifier(AppRouteDestinationModifier(container: container))
        }
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
}

struct AppSectionContent: View {
    let section: AppSection
    let homeViewModel: HomeViewModel
    let container: AppContainer
    var tvSearchRequest: TVSearchRequest? = nil
    var settingsFocusTarget: SettingsFocusTarget? = nil
    var countryFocusReturn = CountryFocusReturn()
    var tvOpenTopLevelDestination: @MainActor (TVTopLevelDestination) -> Void = { _ in }

    var body: some View {
        sectionRoot
            .environment(\.countryFocusReturn, countryFocusReturn)
            .environment(\.openTVTopLevelDestination, tvOpenTopLevelDestination)
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
                topLevelRequest: tvSearchRequest
            )
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
                favoritesStore: container.favoritesStore,
                focusTarget: settingsFocusTarget
            )
        }
    }
}
