import SwiftUI

struct AppRouteDestinationModifier: ViewModifier {
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
                favoritesStore: container.favoritesStore
            )
        case .search:
            SearchView(
                searchChannels: container.searchChannels,
                favoritesStore: container.favoritesStore
            )
        case .searchCategory(let categoryID):
            SearchView(
                searchChannels: container.searchChannels,
                favoritesStore: container.favoritesStore,
                initialCategoryID: categoryID
            )
        case .about:
            AboutView()
        case .country(let code):
            ChannelGridView(
                countryCode: code,
                loadChannels: container.loadChannelsByCountry,
                favoritesStore: container.favoritesStore
            )
        }
    }
}
