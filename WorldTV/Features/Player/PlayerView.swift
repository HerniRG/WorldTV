import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerViewModel
    #if os(macOS)
    @State private var overlayVisibility = PlayerOverlayVisibility()
    #endif
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
            PlatformPlayerView(
                player: viewModel.player,
                feeds: viewModel.feeds,
                selectedFeedID: viewModel.selectedFeedID,
                onSelectFeed: { viewModel.selectFeed($0) },
                infoView: infoPanel
            )

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
        #if os(macOS)
        .overlay(alignment: .topLeading) {
            topBar
                .padding()
                .opacity(overlayVisibility.isVisible ? 1 : 0)
                .allowsHitTesting(overlayVisibility.isVisible)
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.feeds.count > 1 {
                feedMenu
                    .padding()
                    .opacity(overlayVisibility.isVisible ? 1 : 0)
                    .allowsHitTesting(overlayVisibility.isVisible)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: overlayVisibility.isVisible)
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
        #if os(macOS)
        .onChange(of: viewModel.state) { _, newState in
            overlayVisibility.playbackStateDidChange(newState)
        }
        .background(
            PlayerMouseTrackingView(onMove: {
                overlayVisibility.userInteracted()
            })
        )
        .contentShape(Rectangle())
        .onTapGesture {
            overlayVisibility.userInteracted()
        }
        #endif
        .onDisappear {
            viewModel.stop()
        }
        #if os(tvOS)
        .onExitCommand {
            close()
        }
        #endif
    }

    #if os(macOS)
    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            closeButton
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
    }

    private var closeButton: some View {
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
        .keyboardShortcut(.cancelAction)
    }

    private var feedMenu: some View {
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
        .accessibilityLabel(Text("player.feed"))
        .accessibilityIdentifier("player.feed")
    }

    private var feedSelection: Binding<String?> {
        Binding(
            get: { viewModel.selectedFeedID },
            set: { viewModel.selectFeed($0) }
        )
    }
    #endif

    private var infoPanel: AnyView? {
        guard let info = viewModel.channelInfo else {
            return nil
        }
        return AnyView(ChannelInfoPanelView(info: info))
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

#if os(macOS)
private struct PlayerMouseTrackingView: NSViewRepresentable {
    let onMove: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingHostView(onMove: onMove)
        view.addTrackingRect(view.bounds, owner: view, userData: nil, assumeInside: true)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let view = view as? TrackingHostView else {
            return
        }
        view.onMove = onMove
        view.removeTrackingRect(view.trackingTag)
        view.trackingTag = view.addTrackingRect(
            view.bounds,
            owner: view,
            userData: nil,
            assumeInside: true
        )
    }

    final class TrackingHostView: NSView {
        var onMove: () -> Void
        var trackingTag: NSView.TrackingRectTag = 0

        init(onMove: @escaping () -> Void) {
            self.onMove = onMove
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for area in trackingAreas {
                removeTrackingArea(area)
            }
            addTrackingArea(
                NSTrackingArea(
                    rect: .zero,
                    options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved],
                    owner: self,
                    userInfo: nil
                )
            )
        }

        override func mouseMoved(with event: NSEvent) {
            onMove()
        }
    }
}
#endif

private struct PlayerNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationBarTitleDisplayMode(.inline)
        #else
        content
        #endif
    }
}
