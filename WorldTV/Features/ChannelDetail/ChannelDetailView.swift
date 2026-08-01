import SwiftUI

struct ChannelDetailView: View {
    @Environment(\.playChannelWithInitialFeed) private var playChannelWithFeed
    @Environment(\.playerServices) private var playerServices
    #if os(tvOS)
    @State private var presentsPlayer = false
    #endif
    @State private var viewModel: ChannelDetailViewModel
    @State private var selectedFeedID: String?

    private let favoritesStore: FavoritesStore

    init(
        channelID: String,
        loadDetail: LoadChannelDetailUseCase,
        favoritesStore: FavoritesStore
    ) {
        _viewModel = State(
            initialValue: ChannelDetailViewModel(
                channelID: channelID,
                loadDetail: loadDetail
            )
        )
        self.favoritesStore = favoritesStore
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("catalog.loading")
            case .loaded(let content):
                detail(content)
            case .empty:
                ContentUnavailableView("channels.empty", systemImage: "tv.slash")
            case .failed:
                ContentUnavailableView {
                    Label("catalog.error.title", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("action.retry") {
                        viewModel.retry()
                    }
                }
            }
        }
        .platformNavigationTitle("channel.details")
        .task(id: stateIsIdle) {
            await viewModel.loadIfNeeded()
        }
        #if os(tvOS)
        .fullScreenCover(isPresented: $presentsPlayer) {
            if let playerServices, let content = loadedContent {
                PlayerView(
                    channelID: content.channel.id,
                    resolveSources: playerServices.resolveSources,
                    recordRecentlyWatched: playerServices.recordRecentlyWatched,
                    initialFeedID: selectedFeedID,
                    closePresentation: {
                        presentsPlayer = false
                    }
                )
            }
        }
        #endif
    }

    private var stateIsIdle: Bool {
        if case .idle = viewModel.state {
            return true
        }
        return false
    }

    private var loadedContent: ChannelDetailContent? {
        if case .loaded(let content) = viewModel.state {
            return content
        }
        return nil
    }

    private func detail(_ content: ChannelDetailContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                hero(content)
                metadata(content)
                feedSelection(content)
                playButton(content)
                feedsList(content)
            }
            .padding(DesignTokens.pagePadding)
        }
    }

    private func hero(_ content: ChannelDetailContent) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.contentSpacing) {
            HStack(alignment: .top, spacing: 16) {
                logo(content)
                Spacer()
                favoriteButton(content)
            }
            .frame(maxWidth: .infinity)

            Text(content.channel.name)
                .font(.largeTitle.bold())
            HStack(spacing: 16) {
                Label(content.countryName, systemImage: "globe")
                if let quality = content.quality {
                    Label(quality, systemImage: "hifispeaker")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func logo(_ content: ChannelDetailContent) -> some View {
        Group {
            if let logo = content.logo {
                AsyncImage(url: logo.url, transaction: Transaction(animation: .default)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        fallbackLogo
                    @unknown default:
                        fallbackLogo
                    }
                }
                .accessibilityLabel(content.channel.name)
            } else {
                fallbackLogo
            }
        }
        .frame(width: 220, height: 120)
        .accessibilityHidden(true)
    }

    private var fallbackLogo: some View {
        Image(systemName: "tv")
            .font(.system(size: 56))
            .foregroundStyle(.secondary)
            .frame(width: 220, height: 120)
    }

    private func favoriteButton(_ content: ChannelDetailContent) -> some View {
        let isFavorite = favoritesStore.contains(content.channel.id)
        return Button {
            Task {
                await favoritesStore.toggle(content.channel.id)
            }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: DesignTokens.favoriteIconSize, weight: .semibold))
                .foregroundStyle(isFavorite ? .yellow : Color.primary)
                .frame(
                    width: DesignTokens.favoriteButtonSize,
                    height: DesignTokens.favoriteButtonSize
                )
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(FocusedIconButtonStyle())
        .accessibilityLabel(
            isFavorite ? Text("favorites.remove") : Text("favorites.add")
        )
    }

    private func metadata(_ content: ChannelDetailContent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !content.categoryNames.isEmpty {
                Label(
                    content.categoryNames.joined(separator: " · "),
                    systemImage: "square.grid.2x2"
                )
                .font(.subheadline)
            }
            if let network = content.channel.network, !network.isEmpty {
                Label(network, systemImage: "building.2")
                    .font(.subheadline)
            }
            if !content.channel.owners.isEmpty {
                Label(
                    content.channel.owners.joined(separator: " · "),
                    systemImage: "person.2"
                )
                .font(.subheadline)
            }
            if content.isGeoBlocked {
                Label("channel.geo.warning", systemImage: "globe.europe.africa")
                    .font(.footnote)
            }
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func feedSelection(_ content: ChannelDetailContent) -> some View {
        if content.feeds.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("player.feed")
                    .font(.subheadline.weight(.semibold))
                Picker("player.feed", selection: $selectedFeedID) {
                    Text("player.feed.auto").tag(String?.none)
                    ForEach(content.feeds) { feed in
                        Text(feed.displayName).tag(Optional(feed.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 360)
            }
        } else if let feed = content.feeds.first {
            HStack {
                Text("player.feed")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(feed.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func playButton(_ content: ChannelDetailContent) -> some View {
        Button {
            play(content)
        } label: {
            Label("channel.play", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!content.isAvailable)
        .accessibilityIdentifier("channel.detail.play")
    }

    private func play(_ content: ChannelDetailContent) {
        guard content.isAvailable else { return }
        #if os(tvOS)
        presentsPlayer = true
        #else
        playChannelWithFeed(content.channel.id, selectedFeedID)
        #endif
    }

    @ViewBuilder
    private func feedsList(_ content: ChannelDetailContent) -> some View {
        if !content.feeds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("player.feeds")
                    .font(.subheadline.weight(.semibold))
                ForEach(content.feeds) { feed in
                    HStack(spacing: 12) {
                        Text(feed.displayName)
                        Spacer()
                        Text(feedLanguageNames(feed, in: content))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        Color.primary.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
                    )
                }
            }
        }
    }

    private func feedLanguageNames(_ feed: ChannelFeed, in content: ChannelDetailContent) -> String {
        let names = feed.languages.compactMap { code in
            content.languages.first(where: { $0.code == code })?.name
        }
        return names.joined(separator: ", ")
    }
}

private extension ChannelFeed {
    var displayName: String {
        guard let name, !name.isEmpty else {
            return String(localized: "player.feed.auto")
        }
        return name
    }
}

private struct FocusedIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
