import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    let favoritesStore: FavoritesStore

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("catalog.loading")
            case .loaded(let content):
                loadedView(content)
            case .empty:
                ContentUnavailableView {
                    Label("catalog.empty.title", systemImage: "tv.slash")
                } description: {
                    Text("catalog.empty.message")
                } actions: {
                    NavigationTile(
                        route: .sources,
                        tvDestination: .sources,
                        accessibilityID: "home.add.source",
                        tvAccessibilityID: "home.add.source"
                    ) {
                        Label("sources.addButton", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .failed:
                ContentUnavailableView {
                    Label("catalog.error.title", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("catalog.error.message")
                } actions: {
                    Button("action.retry") {
                        viewModel.retry()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await favoritesStore.loadIfNeeded()
            await viewModel.loadIfNeeded()
            NotificationCenter.default.post(name: .topShelfDataDidChange, object: nil)
        }
        .onAppear {
            viewModel.reloadVisibleContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playlistSourcesDidChange)) { _ in
            viewModel.reloadVisibleContent()
        }
        .modifier(CatalogRefreshToolbar(action: viewModel.refresh))
    }

    private func loadedView(_ content: HomeContent) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                header(content.summary)

                let favoriteChannels = visibleFavorites(in: content)
                if !favoriteChannels.isEmpty {
                    channelCarousel(
                        title: "favorites.title",
                        systemImage: "star.fill",
                        channels: favoriteChannels
                    )
                }

                if !content.recentlyWatched.isEmpty {
                    channelCarousel(
                        title: "home.recentlyWatched",
                        systemImage: "clock.arrow.circlepath",
                        channels: content.recentlyWatched
                    )
                }

                if !content.featuredChannels.isEmpty {
                    channelCarousel(
                        title: "home.featured",
                        systemImage: "sparkles.tv",
                        channels: content.featuredChannels
                    )
                }

                sectionTitle("home.popularCountries", systemImage: "flag")
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: DesignTokens.countryGridMinimum),
                            spacing: DesignTokens.contentSpacing
                        )
                    ],
                    spacing: DesignTokens.contentSpacing
                ) {
                    ForEach(content.popularCountries) { item in
                        NavigationTile(
                            route: .country(item.country.code),
                            tvDestination: .searchCountry(item.country.code),
                            accessibilityID: "country.\(item.country.code)",
                            tvAccessibilityID: "home.open.country.\(item.country.code)"
                        ) {
                            CountryCard(item: item)
                        }
                        .worldTVCardButtonStyle()
                    }
                }

                allCountriesAction
                favoritesAction

                if !content.categories.isEmpty {
                    sectionTitle("home.categories", systemImage: "square.grid.2x2")
                    categoryGrid(content.categories)
                }

                if !content.broadcasters.isEmpty {
                    sectionTitle("home.networks", systemImage: "building.2")
                    broadcasterRow(content.broadcasters)
                }
            }
            .padding(DesignTokens.pagePadding)
        }
        .platformNavigationTitle("app.name")
    }

    private func header(_ summary: CatalogSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("home.title")
                .font(.largeTitle.bold())
            Text(
                "\(summary.channelCount.formatted()) \(String(localized: "home.channelCount")) · \(summary.countryCount.formatted()) \(String(localized: "home.countryCount"))"
            )
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.header")
    }

    private func sectionTitle(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title2.bold())
    }

    @ViewBuilder
    private func channelCarousel(
        title: LocalizedStringKey,
        systemImage: String,
        channels: [ChannelCatalogItem]
    ) -> some View {
        sectionTitle(title, systemImage: systemImage)
        HorizontalCarousel(
            items: channels,
            verticalPadding: 14,
            height: DesignTokens.channelCarouselHeight,
            accessibilityIdentifier: "home.channel.carousel"
        ) { item in
            ChannelTile(
                item: item,
                favoritesStore: favoritesStore,
                width: DesignTokens.cardWidth
            )
        }
    }

    private func visibleFavorites(in content: HomeContent) -> [ChannelCatalogItem] {
        var seen: Set<String> = []
        return (
            content.favoriteChannels
                + content.recentlyWatched
                + content.featuredChannels
        )
        .filter { item in
            favoritesStore.contains(item.id) && seen.insert(item.id).inserted
        }
    }

    private func categoryGrid(_ categories: [CategoryCatalogItem]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: DesignTokens.channelGridMinimum),
                    spacing: DesignTokens.contentSpacing
                )
            ],
            spacing: DesignTokens.contentSpacing
        ) {
            ForEach(categories) { item in
                NavigationTile(
                    route: .category(item.category.id),
                    tvDestination: .searchCategory(item.category.id),
                    accessibilityID: "category.\(item.category.id)",
                    tvAccessibilityID: "home.open.category.\(item.category.id)"
                ) {
                    CategoryCard(item: item)
                }
                .worldTVCardButtonStyle()
            }
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    private func broadcasterRow(_ broadcasters: [BroadcasterCatalogItem]) -> some View {
        HorizontalCarousel(
            items: broadcasters,
            verticalPadding: 14,
            height: DesignTokens.broadcasterRowHeight,
            accessibilityIdentifier: "home.broadcaster.carousel"
        ) { item in
            NavigationLink(value: AppRoute.network(item.id)) {
                BroadcasterCard(item: item)
            }
            .worldTVCardButtonStyle()
            .accessibilityIdentifier("broadcaster.\(item.id)")
        }
        .tvShelfBehavior()
    }

    private var allCountriesAction: some View {
        NavigationTile(
            route: .countries,
            tvDestination: .section(.countries),
            tvAccessibilityID: "home.open.countries"
        ) {
            Label("home.allCountries", systemImage: "globe")
        }
        .buttonStyle(.borderedProminent)
    }

    private var favoritesAction: some View {
        NavigationTile(
            route: .favorites,
            tvDestination: .section(.favorites),
            tvAccessibilityID: "home.open.favorites"
        ) {
            Label("favorites.open", systemImage: "star")
        }
        .buttonStyle(.bordered)
    }
}
