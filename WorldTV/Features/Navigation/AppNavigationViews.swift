import SwiftUI

struct AppSectionNavigationStack: View {
    let section: AppSection
    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
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
                imageLoader: container.imageLoader
            )
        case .countries:
            CountriesView(loadCountries: container.loadCountries)
        }
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
        case .country(let code):
            ChannelGridView(
                countryCode: code,
                loadChannels: container.loadChannelsByCountry,
                imageLoader: container.imageLoader
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
