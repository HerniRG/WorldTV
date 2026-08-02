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
                nowPlayingView(content)
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

    @ViewBuilder
    private func nowPlayingView(_ content: ChannelDetailContent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("epg.nowPlaying", systemImage: "clock.badge.checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)

            if let nowPlaying = content.nowPlaying {
                Text(nowPlaying.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(nowPlaying.startTime, format: Date.FormatStyle(date: .abbreviated, time: .shortened))–\(nowPlaying.endTime, format: Date.FormatStyle(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let desc = nowPlaying.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            } else {
                Text("epg.notAvailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func logo(_ content: ChannelDetailContent) -> some View {
        ChannelLogoView(logos: content.logos, channelName: content.channel.name)
        .frame(width: 220, height: 120)
        .accessibilityHidden(true)
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
        let channel = content.channel
        return VStack(alignment: .leading, spacing: 10) {
            if !content.categoryNames.isEmpty {
                Label(
                    content.categoryNames.joined(separator: " · "),
                    systemImage: "square.grid.2x2"
                )
                .font(.subheadline)
            }
            if let network = channel.network, !network.isEmpty {
                Label(network, systemImage: "building.2")
                    .font(.subheadline)
            }
            if !channel.owners.isEmpty {
                Label(
                    channel.owners.joined(separator: " · "),
                    systemImage: "person.2"
                )
                .font(.subheadline)
            }
            if let launched = channel.launched, !launched.isEmpty {
                Label("channel.launched \(launched)", systemImage: "calendar.badge.plus")
                    .font(.subheadline)
            }
            if let closed = channel.closed, !closed.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("channel.closed \(closed)", systemImage: "calendar.badge.minus")
                        .font(.subheadline)
                    if let replacedBy = channel.replacedBy, !replacedBy.isEmpty {
                        HStack(spacing: 8) {
                            Text("channel.replacedBy")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let url = URL(string: "worldtv://channel/\(replacedBy)") {
                                Link(replacedBy, destination: url)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            } else {
                                Text(replacedBy)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if let website = channel.website, !website.isEmpty, let url = URL(string: website) {
                Link("channel.website", destination: url)
                    .font(.subheadline)
            }
            if content.isGeoBlocked {
                Label("channel.geo.warning", systemImage: "globe.europe.africa")
                    .font(.footnote)
            }
            if let blocklistEntry = content.blocklistEntry {
                VStack(alignment: .leading, spacing: 4) {
                    Label("channel.blocked", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    Text(blocklistEntry.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let url = URL(string: blocklistEntry.ref) {
                        Link("channel.blocked.reference", destination: url)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            Text(feed.displayName)
                            Spacer()
                            Text(feedLanguageNames(feed, in: content))
                                .foregroundStyle(.secondary)
                        }
                        
                        if !feed.broadcastArea.isEmpty || !feed.timezones.isEmpty || feed.videoFormat != nil {
                            HStack(spacing: 16) {
                                if !feed.broadcastArea.isEmpty {
                                    Label(feed.broadcastArea.joined(separator: ", "), systemImage: "location")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                if !feed.timezones.isEmpty {
                                    Label(feed.timezones.joined(separator: ", "), systemImage: "clock")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                if let videoFormat = feed.videoFormat, !videoFormat.isEmpty {
                                    Label(videoFormat, systemImage: "tv")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
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

private struct FocusedIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
