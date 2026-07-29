import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerViewModel
    @AppStorage("autoplayChannels") private var autoplayChannels = true
    @AppStorage("preferredQuality") private var preferredQuality = "automatic"

    init(
        channelID: String,
        resolveSources: ResolvePlayableStreamUseCase,
        recordRecentlyWatched: RecordRecentlyWatchedUseCase
    ) {
        _viewModel = State(
            initialValue: PlayerViewModel(
                channelID: channelID,
                resolveSources: resolveSources,
                recordRecentlyWatched: recordRecentlyWatched
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
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
                        dismiss()
                    }
                }
                    .foregroundStyle(.white)
            case .playing, .paused:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityIdentifier("player.fullscreen")
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
            dismiss()
        }
        #endif
    }

    private func progress(_ title: LocalizedStringKey) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(title)
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
            HStack {
                Button("action.retry") {
                    viewModel.retry()
                }
                if viewModel.currentSourceNumber < viewModel.sourceCount {
                    Button("player.tryAnother") {
                        viewModel.tryAnotherSource()
                    }
                }
                Button("player.close") {
                    dismiss()
                }
            }
        }
        .foregroundStyle(.white)
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
