import SwiftUI
import OSLog

private let playerPictureInPictureLogger = Logger(
    subsystem: "com.hernirg.worldtv",
    category: "PictureInPicture"
)

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: PlayerViewModel
    @State private var sleepTimerTask: Task<Void, Never>?
    @State private var selectedSleepTimer: Int?
    @State private var sleepTimerRemainingSeconds: Int?
    @State private var isSleepTimerWarningPresented = false
    #if os(macOS)
    @State private var overlayVisibility = PlayerOverlayVisibility()
    #endif
    @AppStorage("autoplayChannels") private var autoplayChannels = true
    @AppStorage("preferredQuality") private var preferredQuality = "automatic"
    private let closePresentation: (@MainActor () -> Void)?
    private let onPictureInPictureWillStart: @MainActor () -> Void
    private let onPictureInPictureDidStart: @MainActor () -> Void
    private let onPictureInPictureStartFailed: @MainActor () -> Void
    private let onPictureInPictureDidStop: @MainActor () -> Void
    private let restorePresentation: @MainActor (@escaping (Bool) -> Void) -> Void
    private let preservesPlaybackOnDisappear: @MainActor () -> Bool
    private let favoritesStore: FavoritesStore?

    init(
        channelID: String,
        resolveSources: ResolvePlayableStreamUseCase,
        recordRecentlyWatched: RecordRecentlyWatchedUseCase,
        initialFeedID: String? = nil,
        favoritesStore: FavoritesStore? = nil,
        closePresentation: (@MainActor () -> Void)? = nil
    ) {
        self.closePresentation = closePresentation
        self.favoritesStore = favoritesStore
        onPictureInPictureWillStart = {}
        onPictureInPictureDidStart = {}
        onPictureInPictureStartFailed = {}
        onPictureInPictureDidStop = {}
        restorePresentation = { completion in completion(false) }
        preservesPlaybackOnDisappear = { false }
        _viewModel = State(
            initialValue: PlayerViewModel(
                channelID: channelID,
                resolveSources: resolveSources,
                recordRecentlyWatched: recordRecentlyWatched,
                initialFeedID: initialFeedID
            )
        )
    }

    init(
        viewModel: PlayerViewModel,
        favoritesStore: FavoritesStore? = nil,
        closePresentation: @escaping @MainActor () -> Void,
        onPictureInPictureWillStart: @escaping @MainActor () -> Void,
        onPictureInPictureDidStart: @escaping @MainActor () -> Void,
        onPictureInPictureStartFailed: @escaping @MainActor () -> Void,
        onPictureInPictureDidStop: @escaping @MainActor () -> Void,
        restorePresentation: @escaping @MainActor (@escaping (Bool) -> Void) -> Void,
        preservesPlaybackOnDisappear: @escaping @MainActor () -> Bool
    ) {
        _viewModel = State(initialValue: viewModel)
        self.favoritesStore = favoritesStore
        self.closePresentation = closePresentation
        self.onPictureInPictureWillStart = onPictureInPictureWillStart
        self.onPictureInPictureDidStart = onPictureInPictureDidStart
        self.onPictureInPictureStartFailed = onPictureInPictureStartFailed
        self.onPictureInPictureDidStop = onPictureInPictureDidStop
        self.restorePresentation = restorePresentation
        self.preservesPlaybackOnDisappear = preservesPlaybackOnDisappear
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .accessibilityIdentifier("player.fullscreen")
            PlatformPlayerView(
                player: viewModel.player,
                refreshID: viewModel.playerViewRefreshID,
                feeds: viewModel.feeds,
                selectedFeedID: viewModel.selectedFeedID,
                onSelectFeed: { viewModel.selectFeed($0) },
                onPlayerDismissRequested: close,
                onPictureInPictureWillStart: onPictureInPictureWillStart,
                onPictureInPictureDidStart: onPictureInPictureDidStart,
                onPictureInPictureStartFailed: onPictureInPictureStartFailed,
                onPictureInPictureDidStop: onPictureInPictureDidStop,
                onPictureInPictureRestoreRequested: restorePresentation,
                infoView: infoPanel,
                sleepTimerMinutes: sleepTimerMinutes,
                onSleepTimerSelected: setSleepTimer
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

            if isSleepTimerWarningPresented, let remaining = sleepTimerRemainingSeconds {
                SleepTimerWarningView(
                    remainingSeconds: remaining,
                    onCancel: { setSleepTimer(nil) }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
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
            if let favoritesStore {
                await favoritesStore.loadIfNeeded()
            }
            viewModel.loadIfNeeded(
                autoplay: autoplayChannels,
                preferredQuality: Int(preferredQuality)
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            viewModel.applicationDidBecomeActive()
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
            sleepTimerTask?.cancel()
            let preservesPlayback = preservesPlaybackOnDisappear()
            playerPictureInPictureLogger.info(
                "player.disappear preservesPlayback=\(preservesPlayback, privacy: .public)"
            )
            if !preservesPlayback {
                playerPictureInPictureLogger.info("player.disappear stoppingPlayback")
                viewModel.stop()
            }
        }
    }

    #if os(macOS)
    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            closeButton
            sleepTimerMenu
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

    private var sleepTimerMenu: some View {
        Menu {
            sleepTimerOption("player.sleepTimer.off", minutes: nil)
            sleepTimerOption("player.sleepTimer.15", minutes: 15)
            sleepTimerOption("player.sleepTimer.30", minutes: 30)
            sleepTimerOption("player.sleepTimer.60", minutes: 60)
        } label: {
            Label {
                HStack(spacing: 6) {
                    Text("player.sleepTimer")
                    if let selectedSleepTimer {
                        Text("· \(sleepTimerOptionTitle(selectedSleepTimer))")
                    }
                }
            } icon: {
                Image(systemName: "moon.zzz")
            }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func sleepTimerOption(
        _ title: LocalizedStringKey,
        minutes: Int?
    ) -> some View {
        Button {
            setSleepTimer(minutes)
        } label: {
            HStack {
                Text(title)
                Spacer()
                if selectedSleepTimer == minutes {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private func sleepTimerOptionTitle(_ minutes: Int) -> String {
        switch minutes {
        case 15: return String(localized: "player.sleepTimer.15")
        case 30: return String(localized: "player.sleepTimer.30")
        default: return String(localized: "player.sleepTimer.60")
        }
    }
    #endif

    private var sleepTimerMinutes: Int? {
        selectedSleepTimer
    }

    private func setSleepTimer(_ minutes: Int?) {
        sleepTimerTask?.cancel()
        selectedSleepTimer = minutes
        sleepTimerRemainingSeconds = nil
        isSleepTimerWarningPresented = false
        guard let minutes else {
            sleepTimerTask = nil
            return
        }
        #if DEBUG
        let durationInSeconds = minutes == 15 ? 50 : minutes * 60
        #else
        let durationInSeconds = minutes * 60
        #endif
        let endDate = Date.now.addingTimeInterval(TimeInterval(durationInSeconds))
        sleepTimerTask = Task { @MainActor in
            do {
                while !Task.isCancelled {
                    let remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
                    sleepTimerRemainingSeconds = remaining
                    isSleepTimerWarningPresented = remaining > 0 && remaining <= 30
                    if remaining == 0 {
                        viewModel.stop()
                        close()
                        return
                    }
                    try await Task.sleep(for: .seconds(1))
                }
            } catch {
                // Timer cancellation is expected when the user changes it.
            }
        }
    }

    private var infoPanel: AnyView? {
        guard let info = viewModel.channelInfo else {
            return nil
        }
        return AnyView(
            ChannelInfoPanelView(
                info: info,
                favoritesStore: favoritesStore,
                sleepTimerMinutes: selectedSleepTimer,
                onSleepTimerSelected: setSleepTimer
            )
        )
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
            Button("action.retry") {
                viewModel.retry()
            }
            .buttonStyle(.borderedProminent)

            if viewModel.sourceCount > 1 {
                Button("player.tryAnotherSource") {
                    viewModel.tryAnotherSource()
                }
                .buttonStyle(.bordered)
            }

            Button("player.close") {
                close()
            }
        }
        .foregroundStyle(.white)
    }

    private func close() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        selectedSleepTimer = nil
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

private struct SleepTimerWarningView: View {
    let remainingSeconds: Int
    let onCancel: () -> Void
    #if os(tvOS)
    @FocusState private var cancelIsFocused: Bool
    #endif

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 42, weight: .semibold))
                .accessibilityHidden(true)
            Text("player.sleepTimer.warningTitle")
                .font(.title2.bold())
            Text("player.sleepTimer.warningPrefix")
                .foregroundStyle(.secondary)
            Text(format(remainingSeconds))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel(Text("player.sleepTimer.remaining"))
            Button("player.sleepTimer.cancel", action: onCancel)
                .buttonStyle(PlayerActionButtonStyle())
                #if os(tvOS)
                .focused($cancelIsFocused)
                .prefersDefaultFocus(true, in: warningFocusNamespace)
                #endif
        }
        .padding(.horizontal, 54)
        .padding(.vertical, 42)
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 28, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player.sleepTimer.warning")
        #if os(tvOS)
        .focusScope(warningFocusNamespace)
        .focusSection()
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                cancelIsFocused = true
            }
        }
        .onMoveCommand { _ in
            cancelIsFocused = true
        }
        .onExitCommand {
            cancelIsFocused = true
        }
        #endif
    }

    private func format(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    #if os(tvOS)
    @Namespace private var warningFocusNamespace
    #endif
}

#if os(macOS)
private struct PlayerMouseTrackingView: NSViewRepresentable {
    let onMove: () -> Void

    func makeNSView(context: Context) -> NSView {
        TrackingHostView(onMove: onMove)
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let view = view as? TrackingHostView else {
            return
        }
        view.onMove = onMove
    }

    final class TrackingHostView: NSView {
        var onMove: () -> Void

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
