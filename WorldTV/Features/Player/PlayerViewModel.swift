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

    @ObservationIgnored let player = AVPlayer()

    private let channelID: String
    private let resolveSources: ResolvePlayableStreamUseCase
    private let recordRecentlyWatched: RecordRecentlyWatchedUseCase
    private var sources: [PlaybackSource] = []
    private var currentSourceIndex = 0
    private var loadTask: Task<Void, Never>?
    private var endTask: Task<Void, Never>?
    private var sourceTimeoutTask: Task<Void, Never>?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var didRecordPlayback = false
    private var autoplay = true
    private var preferredQuality: Int?

    init(
        channelID: String,
        resolveSources: ResolvePlayableStreamUseCase,
        recordRecentlyWatched: RecordRecentlyWatchedUseCase
    ) {
        self.channelID = channelID
        self.resolveSources = resolveSources
        self.recordRecentlyWatched = recordRecentlyWatched
    }

    func loadIfNeeded(autoplay: Bool = true, preferredQuality: Int? = nil) {
        guard case .idle = state else {
            return
        }

        self.autoplay = autoplay
        self.preferredQuality = preferredQuality
        state = .resolving
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let context = try await resolveSources.execute(
                    channelID: channelID,
                    preferredQuality: preferredQuality
                )
                guard !Task.isCancelled else {
                    return
                }
                channelName = context.channel.name
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
        endTask?.cancel()
        sourceTimeoutTask?.cancel()
        itemStatusObservation = nil
        timeControlObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func playCurrentSource() {
        guard sources.indices.contains(currentSourceIndex) else {
            fail(.allSourcesFailed)
            return
        }

        itemStatusObservation = nil
        timeControlObservation = nil
        endTask?.cancel()
        sourceTimeoutTask?.cancel()
        state = .preparing
        currentSourceNumber = currentSourceIndex + 1

        let item = makePlayerItem(from: sources[currentSourceIndex])
        player.replaceCurrentItem(with: item)
        observe(item)
        startSourceTimeout()
    }

    private func observe(_ item: AVPlayerItem) {
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) {
            [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.handleItemStatus(item.status)
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) {
            [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatus(player.timeControlStatus)
            }
        }

        endTask = Task { [weak self, weak item] in
            guard let item else {
                return
            }
            for await _ in NotificationCenter.default.notifications(
                named: .AVPlayerItemDidPlayToEndTime,
                object: item
            ) {
                guard !Task.isCancelled else {
                    return
                }
                self?.state = .ended
            }
        }
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
            sourceTimeoutTask?.cancel()
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
            state = .paused
        case .waitingToPlayAtSpecifiedRate:
            state = .buffering
        case .playing:
            sourceTimeoutTask?.cancel()
            state = .playing
            if !didRecordPlayback {
                didRecordPlayback = true
                Task {
                    await recordRecentlyWatched.execute(channelID: channelID)
                }
            }
        @unknown default:
            fail(.unavailable)
        }
    }

    private func fail(_ error: PlaybackError) {
        sourceTimeoutTask?.cancel()
        itemStatusObservation = nil
        timeControlObservation = nil
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

    private func startSourceTimeout() {
        sourceTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self else {
                return
            }
            switch state {
            case .preparing, .buffering:
                tryAnotherSource()
            default:
                break
            }
        }
    }
}

extension PlayerViewModel {
    var showsPlayerSurface: Bool {
        switch state {
        case .playing, .buffering, .paused:
            true
        default:
            false
        }
    }

    var showsOverlayClose: Bool {
        switch state {
        case .failed, .ended:
            false
        default:
            true
        }
    }
}
