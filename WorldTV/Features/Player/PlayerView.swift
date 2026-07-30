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
            Color.black
                .ignoresSafeArea()
                .accessibilityIdentifier("player.fullscreen")
            if viewModel.showsPlayerSurface {
                PlatformPlayerView(player: viewModel.player)
                    .accessibilityIdentifier("player.surface")
            }

            switch viewModel.state {
            case .idle, .resolving, .preparing:
                progress("player.preparing")
            case .buffering:
                EmptyView()
            case .failed(let error):
                errorView(error)
            case .ended:
                ContentUnavailableView {
                    Label("player.ended", systemImage: "stop.circle")
                } actions: {
                    Button("player.close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("player.ended.close")
                }
                    .foregroundStyle(.white)
            case .playing, .paused:
                EmptyView()
            }
        }
        #if os(iOS)
        .overlay(alignment: .topLeading) {
            if viewModel.showsStandaloneClose {
                playerCloseButton
            }
        }
        #elseif os(macOS)
        .overlay(alignment: .topLeading) {
            if viewModel.showsOverlayClose {
                playerCloseButton
            }
        }
        #endif
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
            dismiss()
        }
        #endif
    }

    private var playerCloseButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline.bold())
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding()
        .accessibilityLabel(Text("player.close"))
        .accessibilityIdentifier("player.close")
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
            Button("player.close") {
                dismiss()
            }
            .accessibilityIdentifier("player.error.close")
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
