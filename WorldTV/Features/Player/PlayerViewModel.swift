import AVFoundation
import AVKit
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class PlayerViewModel {
    private static let logger = Logger(subsystem: "com.hernirg.worldtv", category: "Playback")
    private(set) var state: PlaybackState = .idle
    private(set) var channelName = ""
    private(set) var currentSourceNumber = 0
    private(set) var sourceCount = 0
    private(set) var currentSourceTitle: String?
    private(set) var feeds: [ChannelFeed] = []
    private(set) var selectedFeedID: String?
    private(set) var channelInfo: PlayerChannelInfo?

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
    private var lastPlaybackError: NSError?

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
                channelInfo = PlayerChannelInfo(
                    name: context.channel.name,
                    broadcasterName: context.channel.broadcasterName,
                    countryName: context.countryName,
                    categoryNames: context.categoryNames,
                    logoURL: context.logoURL,
                    feeds: context.feeds,
                    network: context.channel.network,
                    launched: context.channel.launched
                )
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
        lastPlaybackError = nil

        let item = makePlayerItem(
            from: sources[currentSourceIndex],
            channelName: channelName,
            sourceTitle: sources[currentSourceIndex].title
        )
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
            lastPlaybackError = itemError
            Self.logPlaybackFailure(source: sources[currentSourceIndex], error: itemError)
            attempt?.cancel()
            attempt = nil
            tryAnotherSource()
        @unknown default:
            fail(.unavailable)
        }
    }

    private var itemError: NSError? {
        player.currentItem?.error as NSError?
    }

    private static func logPlaybackFailure(source: PlaybackSource, error: NSError?) {
        let host = source.url.host ?? "unknown-host"
        let path = source.url.path.isEmpty ? "/" : source.url.path
        if let error {
            logger.error("Stream failed host=\(host, privacy: .public) path=\(path, privacy: .public) domain=\(error.domain, privacy: .public) code=\(error.code, privacy: .public) description=\(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("Stream failed host=\(host, privacy: .public) path=\(path, privacy: .public) without AVPlayer error")
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
            NotificationCenter.default.post(name: .topShelfDataDidChange, object: nil)
        }
    }

    private func fail(_ error: PlaybackError) {
        attempt?.cancel()
        attempt = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        state = .failed(error)
    }

    private func makePlayerItem(
        from source: PlaybackSource,
        channelName: String,
        sourceTitle: String?
    ) -> AVPlayerItem {
        var headers: [String: String] = [:]
        if let referrer = source.referrer, !referrer.isEmpty {
            headers["Referer"] = referrer
        }
        if let userAgent = source.userAgent, !userAgent.isEmpty {
            headers["User-Agent"] = userAgent
        }
        let item: AVPlayerItem
        if headers.isEmpty {
            item = AVPlayerItem(url: source.url)
        } else {
            let asset = AVURLAsset(
                url: source.url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
            )
            item = AVPlayerItem(asset: asset)
        }
        #if os(iOS) || os(tvOS)
        item.externalMetadata = Self.makeMetadata(
            channelName: channelName,
            sourceTitle: sourceTitle
        )
        #endif
        return item
    }

    #if os(iOS) || os(tvOS)
    private static func makeMetadata(
        channelName: String,
        sourceTitle: String?
    ) -> [AVMetadataItem] {
        let posixLocale = Locale(identifier: "en_US_POSIX")

        let title = AVMutableMetadataItem()
        title.identifier = .commonIdentifierTitle
        title.keySpace = .common
        title.locale = posixLocale
        title.value = channelName as NSString

        var items: [AVMetadataItem] = [title]

        if let sourceTitle, !sourceTitle.isEmpty {
            let subtitle = AVMutableMetadataItem()
            subtitle.identifier = .iTunesMetadataTrackSubTitle
            subtitle.keySpace = .iTunes
            subtitle.locale = posixLocale
            subtitle.value = sourceTitle as NSString
            items.append(subtitle)
        }
        return items
    }
    #endif
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
