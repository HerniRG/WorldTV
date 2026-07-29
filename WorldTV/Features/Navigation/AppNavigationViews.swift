import SwiftUI

struct AppSectionNavigationStack: View {
    @State private var presentedPlayer: PresentedPlayer?

    let section: AppSection
    let homeViewModel: HomeViewModel
    let container: AppContainer
    var tvSearchRequest: TVSearchRequest?
    var tvOpenTopLevelDestination: @MainActor (TVTopLevelDestination) -> Void = { _ in }

    var body: some View {
        #if os(tvOS)
        navigationStack
            .environment(\.playChannel) { channelID in
                presentedPlayer = PresentedPlayer(channelID: channelID)
            }
            .fullScreenCover(item: $presentedPlayer) { presentation in
                PlayerView(
                    channelID: presentation.channelID,
                    resolveSources: container.resolvePlaybackSources,
                    recordRecentlyWatched: container.recordRecentlyWatched
                )
                .id(presentation.id)
            }
        #else
        navigationStack
        #endif
    }

    private var navigationStack: some View {
        NavigationStack {
            sectionRoot
                .modifier(AppRouteDestinationModifier(container: container))
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
                initialCategoryID: tvSearchRequest?.categoryID
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

private struct PresentedPlayer: Identifiable {
    let channelID: String

    var id: String {
        channelID
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
        case .player(let channelID):
            PlayerView(
                channelID: channelID,
                resolveSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched
            )
        }
    }
}
