import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    let imageLoader: any ImageLoading
    let favoritesStore: FavoritesStore
    var openTVTopLevelDestination: @MainActor (TVTopLevelDestination) -> Void = { _ in }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("catalog.loading")
            case .loaded(let content):
                loadedView(content)
            case .empty:
                ContentUnavailableView(
                    "catalog.empty.title",
                    systemImage: "tv.slash",
                    description: Text("catalog.empty.message")
                )
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
            viewModel.loadIfNeeded()
        }
        .onAppear {
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
                        NavigationLink(value: AppRoute.country(item.country.code)) {
                            CountryCard(item: item)
                        }
                        .worldTVCardButtonStyle()
                    }
                }

                allCountriesAction
                favoritesAction

                if !content.categories.isEmpty {
                    sectionTitle("home.categories", systemImage: "square.grid.2x2")
                    categoryChips(content.categories)
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
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DesignTokens.contentSpacing) {
                ForEach(channels) { item in
                    ChannelTile(
                        item: item,
                        imageLoader: imageLoader,
                        favoritesStore: favoritesStore,
                        width: DesignTokens.cardWidth
                    )
                }
            }
            .padding(.vertical, 14)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .accessibilityIdentifier("home.channel.carousel")
        #if !os(tvOS)
        .contentMargins(
            .horizontal,
            DesignTokens.pagePadding,
            for: .scrollContent
        )
        .padding(.horizontal, -DesignTokens.pagePadding)
        #endif
        .tvShelfBehavior()
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

    private func categoryChips(_ categories: [ChannelCategory]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    #if os(tvOS)
                    Button {
                        openTVTopLevelDestination(.searchCategory(category.id))
                    } label: {
                        categoryLabel(category)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("home.open.category.\(category.id)")
                    #else
                    NavigationLink(value: AppRoute.searchCategory(category.id)) {
                        categoryLabel(category)
                    }
                    .buttonStyle(.bordered)
                    #endif
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .accessibilityIdentifier("home.category.carousel")
        #if !os(tvOS)
        .contentMargins(
            .horizontal,
            DesignTokens.pagePadding,
            for: .scrollContent
        )
        .padding(.horizontal, -DesignTokens.pagePadding)
        #endif
        .tvShelfBehavior()
    }

    @ViewBuilder
    private var allCountriesAction: some View {
        #if os(tvOS)
        Button {
            openTVTopLevelDestination(.section(.countries))
        } label: {
            Label("home.allCountries", systemImage: "globe")
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("home.open.countries")
        #else
        NavigationLink(value: AppRoute.countries) {
            Label("home.allCountries", systemImage: "globe")
        }
        .buttonStyle(.borderedProminent)
        #endif
    }

    @ViewBuilder
    private var favoritesAction: some View {
        #if os(tvOS)
        Button {
            openTVTopLevelDestination(.section(.favorites))
        } label: {
            Label("favorites.open", systemImage: "star")
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("home.open.favorites")
        #else
        NavigationLink(value: AppRoute.favorites) {
            Label("favorites.open", systemImage: "star")
        }
        .buttonStyle(.bordered)
        #endif
    }

    private func categoryLabel(_ category: ChannelCategory) -> some View {
        Text(category.name)
            .font(.headline)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
    }
}
