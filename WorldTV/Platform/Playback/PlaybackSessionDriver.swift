import AVFoundation
import Foundation

enum PlaybackSessionDriverEvent: Sendable {
    case status(AVPlayerItem.Status)
    case timeControl(AVPlayer.TimeControlStatus)
    case timeline(PlaybackTimelineSnapshot)
    case ended
    case preparationTimedOut
    case stalled
}

/// Adapts AVPlayer observations to the platform-independent playback session.
@MainActor
final class PlaybackSessionDriver {
    private(set) var hasStartedPlaying = false

    private let item: AVPlayerItem
    private let player: AVPlayer
    private let preparationTimeout: Duration
    private let stallTimeout: Duration
    private let onEvent: @MainActor (PlaybackSessionDriverEvent) -> Void

    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var endTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var stallTask: Task<Void, Never>?
    private var isRecoveringFromRouteChange = false

    init(
        item: AVPlayerItem,
        player: AVPlayer,
        preparationTimeout: Duration,
        stallTimeout: Duration,
        onEvent: @escaping @MainActor (PlaybackSessionDriverEvent) -> Void
    ) {
        self.item = item
        self.player = player
        self.preparationTimeout = preparationTimeout
        self.stallTimeout = stallTimeout
        self.onEvent = onEvent

        statusObservation = item.observe(\.status, options: [.initial, .new]) {
            [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.onEvent(.status(item.status))
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) {
            [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.onEvent(.timeControl(player.timeControlStatus))
            }
        }
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item else {
                    return
                }
                self.onEvent(.timeline(self.makeTimelineSnapshot(for: item)))
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
                self.onEvent(.ended)
            }
        }
        preparationTask = Task { [weak self, preparationTimeout] in
            try? await Task.sleep(for: preparationTimeout)
            guard !Task.isCancelled, let self else {
                return
            }
            self.onEvent(.preparationTimedOut)
        }
    }

    func markStartedPlaying() {
        hasStartedPlaying = true
        isRecoveringFromRouteChange = false
        preparationTask?.cancel()
        preparationTask = nil
        stallTask?.cancel()
        stallTask = nil
    }

    func armStallTimeout() {
        guard !isRecoveringFromRouteChange, stallTask == nil else {
            return
        }
        stallTask = Task { [weak self, stallTimeout] in
            try? await Task.sleep(for: stallTimeout)
            guard !Task.isCancelled, let self else {
                return
            }
            self.onEvent(.stalled)
        }
    }

    func audioRouteDidChange() {
        isRecoveringFromRouteChange = true
        stallTask?.cancel()
        stallTask = nil
    }

    func cancel() {
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        endTask?.cancel()
        preparationTask?.cancel()
        stallTask?.cancel()
        endTask = nil
        preparationTask = nil
        stallTask = nil
    }

    private func makeTimelineSnapshot(for item: AVPlayerItem) -> PlaybackTimelineSnapshot {
        let ranges = item.seekableTimeRanges.map(\.timeRangeValue)
        let start = ranges.first.flatMap { seconds($0.start) }
        let end = ranges.last.flatMap { seconds($0.end) }
        let duration = seconds(item.duration)

        return PlaybackTimelineSnapshot(
            position: seconds(player.currentTime()),
            duration: duration,
            currentDate: item.currentDate(),
            seekableStart: start,
            seekableEnd: end,
            isLive: item.duration.isIndefinite || (duration == nil && !ranges.isEmpty)
        )
    }

    private func seconds(_ time: CMTime) -> TimeInterval? {
        guard time.isNumeric, time.seconds.isFinite else {
            return nil
        }
        return time.seconds
    }
}
