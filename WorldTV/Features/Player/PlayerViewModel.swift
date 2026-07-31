import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    private(set) var state: PlaybackState = .idle
    private(set) var channelName = ""
    private(set) var currentSourceNumber = 0
    private(set) var sourceCount = 0
    private(set) var currentSourceTitle: String?
    private(set) var feeds: [ChannelFeed] = []
    private(set) var selectedFeedID: String?

    @ObservationIgnored let player = AVPlayer()

    private let channelID: String
    private let resolveSources: ResolvePlayableStreamUseCase
    private let recordRecentlyWatched: RecordRecentlyWatchedUseCase
    private let audioSession = AudioSessionCoordinator()

    private var sources: [PlaybackSource] = []
    private var currentSourceIndex = 0
    private var loadTask: Task<Void, Never>?
    private var attempt: PlaybackAttempt?
    private var didRecordPlayback = false
    private var autoplay = true
    private var preferredQuality: Int?

    init(
        channelID: String,
        resolveSources: ResolvePlayableStreamUseCase,
        recordRecentlyWatched: RecordRecentlyWatchedUseCase,
        initialFeedID: String? = nil
    ) {
        self.channelID = channelID
        self.resolveSources = resolveSources
        self.recordRecentlyWatched = recordRecentlyWatched
        selectedFeedID = initialFeedID
    }

    func loadIfNeeded(autoplay: Bool = true, preferredQuality: Int? = nil) {
        guard case .idle = state else {
            return
        }

        audioSession.activate(player: player)

        self.autoplay = autoplay
        self.preferredQuality = preferredQuality
        state = .resolving
        currentSourceTitle = nil
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let context = try await resolveSources.execute(
                    channelID: channelID,
                    preferredQuality: preferredQuality,
                    feedID: selectedFeedID
                )
                guard !Task.isCancelled else {
                    return
                }
                channelName = context.channel.name
                feeds = context.feeds
                sources = context.sources
                sourceCount = sources.count
                currentSourceIndex = 0
                playCurrentSource()
            } catch let error as PlaybackError {
                fail(error)
            } catch {
                fail(.unavailable)
            }
        }
    }

    func selectFeed(_ feedID: String?) {
        guard feedID != selectedFeedID else {
            return
        }
        loadTask?.cancel()
        attempt?.cancel()
        attempt = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        selectedFeedID = feedID
        state = .idle
        loadIfNeeded(autoplay: autoplay, preferredQuality: preferredQuality)
    }

    func retry() {
        guard !sources.isEmpty else {
            state = .idle
            loadIfNeeded(autoplay: autoplay, preferredQuality: preferredQuality)
            return
        }
        currentSourceIndex = 0
        playCurrentSource()
    }

    func tryAnotherSource() {
        guard currentSourceIndex + 1 < sources.count else {
            fail(.allSourcesFailed)
            return
        }
        currentSourceIndex += 1
        playCurrentSource()
    }

    func stop() {
        loadTask?.cancel()
        attempt?.cancel()
        attempt = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func playCurrentSource() {
        guard sources.indices.contains(currentSourceIndex) else {
            fail(.allSourcesFailed)
            return
        }

        attempt?.cancel()
        state = .preparing
        currentSourceNumber = currentSourceIndex + 1
        currentSourceTitle = sources[currentSourceIndex].title

        let item = makePlayerItem(from: sources[currentSourceIndex])
        player.replaceCurrentItem(with: item)

        let nextAttempt = PlaybackAttempt(
            item: item,
            player: player,
            preparationTimeout: .seconds(15),
            stallTimeout: .seconds(20),
            onStatus: { [weak self] status in
                self?.handleItemStatus(status)
            },
            onTimeControl: { [weak self] status in
                self?.handleTimeControlStatus(status)
            },
            onEnded: { [weak self] in
                self?.state = .ended
            },
            onPreparationTimedOut: { [weak self] in
                self?.tryAnotherSource()
            },
            onStalled: { [weak self] in
                self?.tryAnotherSource()
            }
        )
        attempt = nextAttempt
        nextAttempt.start()
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .unknown:
            state = .preparing
        case .readyToPlay:
            if autoplay {
                player.play()
            } else {
                state = .paused
            }
        case .failed:
            attempt?.cancel()
            attempt = nil
            tryAnotherSource()
        @unknown default:
            fail(.unavailable)
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard player.currentItem?.status == .readyToPlay else {
            return
        }
        switch status {
        case .paused:
            if attempt?.hasStartedPlaying == true {
                state = .paused
            }
        case .waitingToPlayAtSpecifiedRate:
            if attempt?.hasStartedPlaying == true {
                attempt?.armStallTimeout()
                state = .buffering
            } else {
                state = .buffering
            }
        case .playing:
            attempt?.markStartedPlaying()
            state = .playing
            recordPlaybackIfNeeded()
        @unknown default:
            fail(.unavailable)
        }
    }

    private func recordPlaybackIfNeeded() {
        guard !didRecordPlayback else {
            return
        }
        didRecordPlayback = true
        Task {
            await recordRecentlyWatched.execute(channelID: channelID)
        }
    }

    private func fail(_ error: PlaybackError) {
        attempt?.cancel()
        attempt = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        state = .failed(error)
    }

    private func makePlayerItem(from source: PlaybackSource) -> AVPlayerItem {
        var headers: [String: String] = [:]
        if let referrer = source.referrer, !referrer.isEmpty {
            headers["Referer"] = referrer
        }
        if let userAgent = source.userAgent, !userAgent.isEmpty {
            headers["User-Agent"] = userAgent
        }
        guard !headers.isEmpty else {
            return AVPlayerItem(url: source.url)
        }

        let asset = AVURLAsset(
            url: source.url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
        )
        return AVPlayerItem(asset: asset)
    }
}

@MainActor
private final class PlaybackAttempt {
    private(set) var hasStartedPlaying = false

    private let item: AVPlayerItem
    private let preparationTimeout: Duration
    private let stallTimeout: Duration
    private let onStatus: @MainActor (AVPlayerItem.Status) -> Void
    private let onTimeControl: @MainActor (AVPlayer.TimeControlStatus) -> Void
    private let onEnded: @MainActor () -> Void
    private let onPreparationTimedOut: @MainActor () -> Void
    private let onStalled: @MainActor () -> Void

    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var endTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var stallTask: Task<Void, Never>?

    init(
        item: AVPlayerItem,
        player: AVPlayer,
        preparationTimeout: Duration,
        stallTimeout: Duration,
        onStatus: @escaping @MainActor (AVPlayerItem.Status) -> Void,
        onTimeControl: @escaping @MainActor (AVPlayer.TimeControlStatus) -> Void,
        onEnded: @escaping @MainActor () -> Void,
        onPreparationTimedOut: @escaping @MainActor () -> Void,
        onStalled: @escaping @MainActor () -> Void
    ) {
        self.item = item
        self.preparationTimeout = preparationTimeout
        self.stallTimeout = stallTimeout
        self.onStatus = onStatus
        self.onTimeControl = onTimeControl
        self.onEnded = onEnded
        self.onPreparationTimedOut = onPreparationTimedOut
        self.onStalled = onStalled

        statusObservation = item.observe(\.status, options: [.initial, .new]) {
            [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.onStatus(item.status)
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) {
            [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.onTimeControl(player.timeControlStatus)
            }
        }
    }

    func start() {
        endTask = Task { [weak self, weak item] in
            guard let item else {
                return
            }
            for await _ in NotificationCenter.default.notifications(
                named: .AVPlayerItemDidPlayToEndTime,
                object: item
            ) {
                guard !Task.isCancelled, let self else {
                    return
                }
                self.onEnded()
            }
        }
        preparationTask = Task { [weak self, preparationTimeout] in
            try? await Task.sleep(for: preparationTimeout)
            guard !Task.isCancelled, let self else {
                return
            }
            self.onPreparationTimedOut()
        }
    }

    func markStartedPlaying() {
        hasStartedPlaying = true
        preparationTask?.cancel()
        preparationTask = nil
        stallTask?.cancel()
        stallTask = nil
    }

    func armStallTimeout() {
        guard stallTask == nil else {
            return
        }
        stallTask = Task { [weak self, stallTimeout] in
            try? await Task.sleep(for: stallTimeout)
            guard !Task.isCancelled, let self else {
                return
            }
            self.onStalled()
        }
    }

    func cancel() {
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        endTask?.cancel()
        preparationTask?.cancel()
        stallTask?.cancel()
    }
}
