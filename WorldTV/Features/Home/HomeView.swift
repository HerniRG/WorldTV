import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    let imageLoader: any ImageLoading

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
                        .buttonStyle(FocusedCardButtonStyle())
                    }
                }

                NavigationLink(value: AppRoute.countries) {
                    Label("home.allCountries", systemImage: "globe")
                }
                .buttonStyle(.borderedProminent)

                if !content.categories.isEmpty {
                    sectionTitle("home.categories", systemImage: "square.grid.2x2")
                    categoryChips(content.categories)
                }
            }
            .padding(DesignTokens.pagePadding)
        }
        .navigationTitle("app.name")
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
                    NavigationLink(value: AppRoute.player(item.id)) {
                        ChannelCard(item: item, imageLoader: imageLoader)
                            .frame(width: DesignTokens.cardWidth)
                    }
                    .buttonStyle(FocusedCardButtonStyle())
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func categoryChips(_ categories: [ChannelCategory]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    Text(category.name)
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                }
            }
        }
    }
}
