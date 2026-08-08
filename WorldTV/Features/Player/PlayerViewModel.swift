import AVFoundation
import AVKit
import Foundation
import Observation
import OSLog
#if os(iOS) || os(tvOS)
import UIKit
#endif

@Observable
@MainActor
final class PlayerViewModel {
    private static let logger = Logger(subsystem: "com.hernirg.worldtv", category: "Playback")
    private(set) var state: PlaybackState = .idle
    private(set) var streamState: PlaybackSessionState = .idle
    private(set) var channelName = ""
    private(set) var currentSourceNumber = 0
    private(set) var sourceCount = 0
    private(set) var currentSourceTitle: String?
    private(set) var feeds: [ChannelFeed] = []
    private(set) var selectedFeedID: String?
    private(set) var channelInfo: PlayerChannelInfo?
    private(set) var playerViewRefreshID = 0
    private(set) var timeline: PlaybackTimelineSnapshot?

    @ObservationIgnored let player = AVPlayer()

    private let channelID: String
    private let resolveSources: ResolvePlayableStreamUseCase
    private let recordRecentlyWatched: RecordRecentlyWatchedUseCase
    private let audioSession = AudioSessionCoordinator()

    private var sources: [PlaybackSource] = []
    private var playbackSession: PlaybackSession?
    private var currentSourceIndex = 0
    private var loadTask: Task<Void, Never>?
    private var sessionDriver: PlaybackSessionDriver?
    private var artworkTask: Task<Void, Never>?
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
                playbackSession = PlaybackSession(sources: sources)
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
        sessionDriver?.cancel()
        sessionDriver = nil
        artworkTask?.cancel()
        artworkTask = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        selectedFeedID = feedID
        playbackSession = nil
        timeline = nil
        streamState = .idle
        state = .idle
        loadIfNeeded(autoplay: autoplay, preferredQuality: preferredQuality)
    }

    func retry() {
        guard !sources.isEmpty else {
            state = .idle
            loadIfNeeded(autoplay: autoplay, preferredQuality: preferredQuality)
            return
        }
        if var playbackSession {
            _ = playbackSession.retry()
            self.playbackSession = playbackSession
            currentSourceIndex = playbackSession.currentSourceIndex
            timeline = nil
        } else {
            currentSourceIndex = 0
        }
        playCurrentSource()
    }

    func tryAnotherSource() {
        if var playbackSession {
            let action = playbackSession.handle(.sourceFailed)
            self.playbackSession = playbackSession
            switch action {
            case .prepareSource(let index):
                currentSourceIndex = index
                playCurrentSource()
            case .failed(let error):
                fail(error)
            case .none, .ended:
                fail(.unavailable)
            }
            return
        }

        guard currentSourceIndex + 1 < sources.count else {
            fail(.allSourcesFailed)
            return
        }
        currentSourceIndex += 1
        playCurrentSource()
    }

    func stop() {
        loadTask?.cancel()
        sessionDriver?.cancel()
        sessionDriver = nil
        playbackSession = nil
        timeline = nil
        streamState = .idle
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func applicationDidBecomeActive() {
        guard
            player.currentItem != nil,
            streamState == .playing || streamState == .paused || streamState == .buffering
        else {
            return
        }

        _ = playbackSession?.handle(.becameActive)
        syncStateFromPlaybackSession()
        playerViewRefreshID += 1
    }

    private func playCurrentSource() {
        guard sources.indices.contains(currentSourceIndex) else {
            fail(.allSourcesFailed)
            return
        }

        sessionDriver?.cancel()
        artworkTask?.cancel()
        artworkTask = nil
        if var playbackSession {
            if playbackSession.state == .idle {
                _ = playbackSession.start()
            }
            self.playbackSession = playbackSession
            currentSourceIndex = playbackSession.currentSourceIndex
            syncStateFromPlaybackSession()
        } else {
            state = .preparing
        }
        currentSourceNumber = currentSourceIndex + 1
        currentSourceTitle = sources[currentSourceIndex].title
        lastPlaybackError = nil

        let item = makePlayerItem(
            from: sources[currentSourceIndex],
            channelName: channelName,
            sourceTitle: sources[currentSourceIndex].title
        )
        player.replaceCurrentItem(with: item)
        #if os(iOS) || os(tvOS)
        loadChannelArtwork(
            for: item,
            logoURL: channelInfo?.logoURL,
            channelName: channelName,
            sourceTitle: sources[currentSourceIndex].title
        )
        #endif

        let nextDriver = PlaybackSessionDriver(
            item: item,
            player: player,
            preparationTimeout: .seconds(15),
            stallTimeout: .seconds(20),
            onEvent: { [weak self] event in
                self?.handleSessionDriverEvent(event)
            }
        )
        sessionDriver = nextDriver
        nextDriver.start()
    }

    private func handleSessionDriverEvent(
        _ event: PlaybackSessionDriverEvent
    ) {
        switch event {
        case .status(let status):
            handleItemStatus(status)
        case .timeControl(let status):
            handleTimeControlStatus(status)
        case .timeline(let snapshot):
            _ = playbackSession?.handle(.timeline(snapshot))
            timeline = snapshot
        case .ended:
            handlePlaybackEnded()
        case .preparationTimedOut, .stalled:
            tryAnotherSource()
        }
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .unknown:
            syncStateFromPlaybackSession()
        case .readyToPlay:
            if autoplay {
                player.play()
            } else {
                _ = playbackSession?.handle(.paused)
                syncStateFromPlaybackSession()
            }
        case .failed:
            lastPlaybackError = itemError
            Self.logPlaybackFailure(source: sources[currentSourceIndex], error: itemError)
            sessionDriver?.cancel()
            sessionDriver = nil
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
            if sessionDriver?.hasStartedPlaying == true {
                _ = playbackSession?.handle(.paused)
                syncStateFromPlaybackSession()
            }
        case .waitingToPlayAtSpecifiedRate:
            if sessionDriver?.hasStartedPlaying == true {
                sessionDriver?.armStallTimeout()
            }
            _ = playbackSession?.handle(.waiting)
            syncStateFromPlaybackSession()
        case .playing:
            sessionDriver?.markStartedPlaying()
            _ = playbackSession?.handle(.started)
            syncStateFromPlaybackSession()
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
        sessionDriver?.cancel()
        sessionDriver = nil
        artworkTask?.cancel()
        artworkTask = nil
        _ = playbackSession?.handle(.failed(error))
        player.pause()
        player.replaceCurrentItem(with: nil)
        syncStateFromPlaybackSession(fallback: .failed(error))
    }

    private func handlePlaybackEnded() {
        _ = playbackSession?.handle(.ended)
        syncStateFromPlaybackSession(fallback: .ended)
    }

    private func syncStateFromPlaybackSession(
        fallback: PlaybackState? = nil
    ) {
        guard let session = playbackSession else {
            if let fallback {
                streamState = sessionState(for: fallback)
                state = fallback
            }
            return
        }

        streamState = session.state
        timeline = session.timeline

        switch session.state {
        case .idle:
            state = .idle
        case .preparing:
            state = .preparing
        case .playing:
            state = .playing
        case .buffering:
            state = .buffering
        case .paused:
            state = .paused
        case .ended:
            state = .ended
        case .failed(let error):
            state = .failed(error)
        }
    }

    private func sessionState(for presentationState: PlaybackState) -> PlaybackSessionState {
        switch presentationState {
        case .idle, .resolving:
            return .idle
        case .preparing:
            return .preparing
        case .playing:
            return .playing
        case .buffering:
            return .buffering
        case .paused:
            return .paused
        case .failed(let error):
            return .failed(error)
        case .ended:
            return .ended
        }
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
            sourceTitle: sourceTitle,
            artworkData: Self.applicationArtworkData()
        )
        #endif
        return item
    }

    #if os(iOS) || os(tvOS)
    private func loadChannelArtwork(
        for item: AVPlayerItem,
        logoURL: URL?,
        channelName: String,
        sourceTitle: String?
    ) {
        artworkTask?.cancel()
        artworkTask = nil

        guard let logoURL else {
            return
        }

        artworkTask = Task { [weak self, weak item] in
            do {
                let (data, response) = try await URLSession.shared.data(from: logoURL)
                guard
                    !Task.isCancelled,
                    let httpResponse = response as? HTTPURLResponse,
                    200..<300 ~= httpResponse.statusCode,
                    !data.isEmpty,
                    UIImage(data: data) != nil,
                    let artworkData = Self.paddedArtworkData(data),
                    let self,
                    let item,
                    self.player.currentItem === item
                else {
                    return
                }
                item.externalMetadata = Self.makeMetadata(
                    channelName: channelName,
                    sourceTitle: sourceTitle,
                    artworkData: artworkData
                )
            } catch is CancellationError {
                return
            } catch {
                // The application artwork already provides a visible fallback.
            }
        }
    }

    private static func makeMetadata(
        channelName: String,
        sourceTitle: String?,
        artworkData: Data?
    ) -> [AVMetadataItem] {
        let posixLocale = Locale(identifier: "en_US_POSIX")

        let title = AVMutableMetadataItem()
        title.identifier = .commonIdentifierTitle
        title.keySpace = .common
        title.locale = posixLocale
        title.value = channelName as NSString

        var items: [AVMetadataItem] = [title]

        if let artworkData, !artworkData.isEmpty {
            let artwork = AVMutableMetadataItem()
            artwork.identifier = .commonIdentifierArtwork
            artwork.keySpace = .common
            artwork.locale = posixLocale
            artwork.value = artworkData as NSData
            items.append(artwork)
        }

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

    private static func applicationArtworkData() -> Data? {
        UIImage(named: "AppIcon")?.pngData()
    }

    private static func paddedArtworkData(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let canvasSize = CGSize(width: 512, height: 512)
        let maximumImageSize = CGSize(width: 370, height: 370)
        let scale = min(
            maximumImageSize.width / image.size.width,
            maximumImageSize.height / image.size.height
        )
        let imageSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let imageRect = CGRect(
            x: (canvasSize.width - imageSize.width) / 2,
            y: (canvasSize.height - imageSize.height) / 2,
            width: imageSize.width,
            height: imageSize.height
        )

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { _ in
            image.draw(in: imageRect)
        }.pngData()
    }
    #endif
}
