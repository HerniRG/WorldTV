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
        case .category(let id):
            CategoryGridView(
                categoryID: id,
                loadChannels: container.loadChannelsByCategory,
                favoritesStore: container.favoritesStore
            )
        case .channel(let id):
            ChannelDetailView(
                channelID: id,
                loadDetail: container.loadChannelDetail,
                favoritesStore: container.favoritesStore
            )
        case .network(let id):
            NetworkChannelGridView(
                broadcasterID: id,
                loadChannels: container.loadChannelsByBroadcaster,
                favoritesStore: container.favoritesStore
            )
        }
    }
}
