import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerViewModel
    @AppStorage("autoplayChannels") private var autoplayChannels = true
    @AppStorage("preferredQuality") private var preferredQuality = "automatic"
    private let closePresentation: (@MainActor () -> Void)?

    init(
        channelID: String,
        resolveSources: ResolvePlayableStreamUseCase,
        recordRecentlyWatched: RecordRecentlyWatchedUseCase,
        initialFeedID: String? = nil,
        closePresentation: (@MainActor () -> Void)? = nil
    ) {
        self.closePresentation = closePresentation
        _viewModel = State(
            initialValue: PlayerViewModel(
                channelID: channelID,
                resolveSources: resolveSources,
                recordRecentlyWatched: recordRecentlyWatched,
                initialFeedID: initialFeedID
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .accessibilityIdentifier("player.fullscreen")
            PlatformPlayerView(player: viewModel.player)

            switch viewModel.state {
            case .idle, .resolving, .preparing:
                progress("player.preparing")
            case .buffering:
                progress("player.buffering")
            case .failed(let error):
                errorView(error)
            case .ended:
                ContentUnavailableView {
                    Label("player.ended", systemImage: "stop.circle")
                } actions: {
                    Button("player.close") {
                        close()
                    }
                }
                    .foregroundStyle(.white)
            case .playing, .paused:
                EmptyView()
            }
        }
        #if os(iOS) || os(macOS)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("player.close"))
                .accessibilityIdentifier("player.close")

                if let title = viewModel.currentSourceTitle {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .accessibilityIdentifier("player.source.title")
                }
            }
            .padding()
        }
        #endif
        .overlay(alignment: .topTrailing) {
            if viewModel.feeds.count > 1 {
                Menu {
                    Picker("player.feed", selection: feedSelection) {
                        Text("player.feed.auto").tag(String?.none)
                        ForEach(viewModel.feeds) { feed in
                            Text(feed.name ?? feed.id).tag(Optional(feed.id))
                        }
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.headline.bold())
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding()
                .accessibilityLabel(Text("player.feed"))
                .accessibilityIdentifier("player.feed")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .platformNavigationTitle(verbatim: viewModel.channelName)
        .modifier(PlayerNavigationStyle())
        .task {
            viewModel.loadIfNeeded(
                autoplay: autoplayChannels,
                preferredQuality: Int(preferredQuality)
            )
        }
        .onDisappear {
            viewModel.stop()
        }
        #if os(tvOS)
        .onExitCommand {
            close()
        }
        #endif
    }

    private func progress(_ title: LocalizedStringKey) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(title)
            if let sourceTitle = viewModel.currentSourceTitle {
                Text(sourceTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if viewModel.sourceCount > 1 {
                Text(
                    "\(viewModel.currentSourceNumber) / \(viewModel.sourceCount)"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func errorView(_ error: PlaybackError) -> some View {
        ContentUnavailableView {
            Label("player.error.title", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message(for: error))
        } actions: {
            Button("player.close") {
                close()
            }
        }
        .foregroundStyle(.white)
    }

    private func close() {
        viewModel.stop()
        if let closePresentation {
            closePresentation()
        } else {
            dismiss()
        }
    }

    private var feedSelection: Binding<String?> {
        Binding(
            get: { viewModel.selectedFeedID },
            set: { viewModel.selectFeed($0) }
        )
    }

    private func message(for error: PlaybackError) -> LocalizedStringKey {
        switch error {
        case .channelNotFound:
            "player.error.channelNotFound"
        case .noSources:
            "player.error.noSources"
        case .allSourcesFailed:
            "player.error.allSourcesFailed"
        case .unavailable:
            "player.error.unavailable"
        }
    }
}

private struct PlayerNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationBarTitleDisplayMode(.inline)
        #else
        content
        #endif
    }
}
