import AVKit
import OSLog
import SwiftUI

private let pictureInPictureLogger = Logger(
    subsystem: "com.hernirg.worldtv",
    category: "PictureInPicture"
)

#if os(iOS) || os(tvOS)
private final class PictureInPictureRestoreCompletion: @unchecked Sendable {
    private let handler: (Bool) -> Void

    init(_ handler: @escaping (Bool) -> Void) {
        self.handler = handler
    }

    @MainActor
    func callAsFunction(_ restored: Bool) {
        handler(restored)
    }
}
#endif

#if os(macOS)
struct PlatformPlayerView: NSViewRepresentable {
    let player: AVPlayer
    let refreshID: Int
    let feeds: [ChannelFeed]
    let selectedFeedID: String?
    let onSelectFeed: @MainActor (String?) -> Void
    let onPlayerDismissRequested: @MainActor () -> Void
    let onPictureInPictureWillStart: @MainActor () -> Void
    let onPictureInPictureDidStart: @MainActor () -> Void
    let onPictureInPictureStartFailed: @MainActor () -> Void
    let onPictureInPictureDidStop: @MainActor () -> Void
    let onPictureInPictureRestoreRequested: @MainActor (@escaping (Bool) -> Void) -> Void
    let infoView: AnyView?
    let sleepTimerMinutes: Int?
    let onSleepTimerSelected: @MainActor (Int?) -> Void
    let isSleepTimerWarningPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = true
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
        if context.coordinator.lastRefreshID != refreshID {
            context.coordinator.lastRefreshID = refreshID
            view.player = nil
            view.player = player
        }
    }

    final class Coordinator {
        var lastRefreshID = 0
    }
}
#elseif os(iOS)
struct PlatformPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let refreshID: Int
    let feeds: [ChannelFeed]
    let selectedFeedID: String?
    let onSelectFeed: @MainActor (String?) -> Void
    let onPlayerDismissRequested: @MainActor () -> Void
    let onPictureInPictureWillStart: @MainActor () -> Void
    let onPictureInPictureDidStart: @MainActor () -> Void
    let onPictureInPictureStartFailed: @MainActor () -> Void
    let onPictureInPictureDidStop: @MainActor () -> Void
    let onPictureInPictureRestoreRequested: @MainActor (@escaping (Bool) -> Void) -> Void
    let infoView: AnyView?
    let sleepTimerMinutes: Int?
    let onSleepTimerSelected: @MainActor (Int?) -> Void
    let isSleepTimerWarningPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPictureInPictureWillStart: onPictureInPictureWillStart,
            onPictureInPictureDidStart: onPictureInPictureDidStart,
            onPictureInPictureStartFailed: onPictureInPictureStartFailed,
            onPictureInPictureDidStop: onPictureInPictureDidStop,
            onPictureInPictureRestoreRequested:
                onPictureInPictureRestoreRequested
        )
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.onPictureInPictureDidStart = onPictureInPictureDidStart
        context.coordinator.onPictureInPictureStartFailed = onPictureInPictureStartFailed
        context.coordinator.onPictureInPictureDidStop = onPictureInPictureDidStop
        context.coordinator.onPictureInPictureWillStart = onPictureInPictureWillStart
        context.coordinator.onPictureInPictureRestoreRequested =
            onPictureInPictureRestoreRequested
        controller.player = player
        if context.coordinator.lastRefreshID != refreshID {
            context.coordinator.lastRefreshID = refreshID
            controller.player = nil
            controller.player = player
        }
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var lastRefreshID = 0
        var onPictureInPictureWillStart: @MainActor () -> Void
        var onPictureInPictureDidStart: @MainActor () -> Void
        var onPictureInPictureStartFailed: @MainActor () -> Void
        var onPictureInPictureDidStop: @MainActor () -> Void
        var onPictureInPictureRestoreRequested: @MainActor (@escaping (Bool) -> Void) -> Void

        init(
            onPictureInPictureWillStart: @escaping @MainActor () -> Void,
            onPictureInPictureDidStart: @escaping @MainActor () -> Void,
            onPictureInPictureStartFailed: @escaping @MainActor () -> Void,
            onPictureInPictureDidStop: @escaping @MainActor () -> Void,
            onPictureInPictureRestoreRequested:
                @escaping @MainActor (@escaping (Bool) -> Void) -> Void
        ) {
            self.onPictureInPictureWillStart = onPictureInPictureWillStart
            self.onPictureInPictureDidStart = onPictureInPictureDidStart
            self.onPictureInPictureStartFailed = onPictureInPictureStartFailed
            self.onPictureInPictureDidStop = onPictureInPictureDidStop
            self.onPictureInPictureRestoreRequested =
                onPictureInPictureRestoreRequested
        }

        func playerViewControllerWillStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            pictureInPictureLogger.info("delegate.willStart")
            let callback = onPictureInPictureWillStart
            MainActor.assumeIsolated {
                callback()
            }
        }

        func playerViewControllerDidStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            pictureInPictureLogger.info("delegate.didStart")
            let callback = onPictureInPictureDidStart
            MainActor.assumeIsolated {
                callback()
            }
        }

        func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
            _ playerViewController: AVPlayerViewController
        ) -> Bool {
            pictureInPictureLogger.info("delegate.autoDismiss=false managedByPresenter")
            return false
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            failedToStartPictureInPictureWithError error: Error
        ) {
            pictureInPictureLogger.error("delegate.startFailed")
            let callback = onPictureInPictureStartFailed
            MainActor.assumeIsolated {
                callback()
            }
        }

        func playerViewControllerDidStopPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            pictureInPictureLogger.info("delegate.didStop")
            let callback = onPictureInPictureDidStop
            MainActor.assumeIsolated {
                callback()
            }
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            pictureInPictureLogger.info("delegate.restoreRequested")
            let restore = onPictureInPictureRestoreRequested
            let completion = PictureInPictureRestoreCompletion(completionHandler)
            MainActor.assumeIsolated {
                restore(completion.callAsFunction)
            }
        }
    }
}

#elseif os(tvOS)
struct PlatformPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let refreshID: Int
    let feeds: [ChannelFeed]
    let selectedFeedID: String?
    let onSelectFeed: @MainActor (String?) -> Void
    let onPlayerDismissRequested: @MainActor () -> Void
    let onPictureInPictureWillStart: @MainActor () -> Void
    let onPictureInPictureDidStart: @MainActor () -> Void
    let onPictureInPictureStartFailed: @MainActor () -> Void
    let onPictureInPictureDidStop: @MainActor () -> Void
    let onPictureInPictureRestoreRequested: @MainActor (@escaping (Bool) -> Void) -> Void
    let infoView: AnyView?
    let sleepTimerMinutes: Int?
    let onSleepTimerSelected: @MainActor (Int?) -> Void
    let isSleepTimerWarningPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPictureInPictureWillStart: onPictureInPictureWillStart,
            onPlayerDismissRequested: onPlayerDismissRequested,
            onPictureInPictureDidStart: onPictureInPictureDidStart,
            onPictureInPictureStartFailed: onPictureInPictureStartFailed,
            onPictureInPictureDidStop: onPictureInPictureDidStop,
            onPictureInPictureRestoreRequested:
                onPictureInPictureRestoreRequested
        )
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.allowsPictureInPicturePlayback = true
        controller.delegate = context.coordinator
        controller.playbackControlsIncludeTransportBar = true
        controller.transportBarIncludesTitleView = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.onPictureInPictureDidStart = onPictureInPictureDidStart
        context.coordinator.onPictureInPictureStartFailed = onPictureInPictureStartFailed
        context.coordinator.onPictureInPictureDidStop = onPictureInPictureDidStop
        context.coordinator.onPlayerDismissRequested = onPlayerDismissRequested
        context.coordinator.onPictureInPictureWillStart = onPictureInPictureWillStart
        context.coordinator.onPictureInPictureRestoreRequested =
            onPictureInPictureRestoreRequested
        controller.player = player
        if context.coordinator.lastRefreshID != refreshID {
            context.coordinator.lastRefreshID = refreshID
            controller.player = nil
            controller.player = player
        }
        controller.transportBarCustomMenuItems = Self.makeFeedMenuItems(
            feeds: feeds,
            selectedFeedID: selectedFeedID,
            onSelectFeed: onSelectFeed
        ) + Self.makeSleepTimerMenuItems(
            selectedMinutes: sleepTimerMinutes,
            onSelect: onSleepTimerSelected
        )
        configureInfoPanel(controller, context: context)
        if isSleepTimerWarningPresented {
            if !context.coordinator.didDismissInfoPanelForSleepTimer {
                context.coordinator.dismissInfoPanel(controller)
                context.coordinator.didDismissInfoPanelForSleepTimer = true
            }
        } else {
            context.coordinator.didDismissInfoPanelForSleepTimer = false
        }
    }

    private func configureInfoPanel(
        _ controller: AVPlayerViewController,
        context: Context
    ) {
        if let infoView {
            let hosting = context.coordinator.infoHostingController ?? {
                let newHosting = UIHostingController(rootView: infoView)
                newHosting.title = String(localized: "player.info")
                newHosting.preferredContentSize = CGSize(width: 880, height: 620)
                newHosting.view.backgroundColor = .clear
                newHosting.safeAreaRegions = []
                context.coordinator.infoHostingController = newHosting
                return newHosting
            }()
            // AVKit can be in the middle of presenting the Info panel when
            // SwiftUI updates this representable (for example, as playback
            // changes state). Reassigning this property on every update makes
            // tvOS tear down and re-measure the panel, which can produce a
            // different vertical placement on the next presentation.
            if !context.coordinator.isInfoPanelInstalled {
                // There is only one custom tab. The legacy singular API avoids
                // the tvOS multi-tab container's repeated relayout on reopen.
                installInfoPanel(controller, hosting: hosting)
                context.coordinator.isInfoPanelInstalled = true
            }
        } else {
            if context.coordinator.isInfoPanelInstalled {
                installInfoPanel(controller, hosting: nil)
                context.coordinator.isInfoPanelInstalled = false
            }
        }
    }

    private func installInfoPanel(
        _ controller: AVPlayerViewController,
        hosting: UIViewController?
    ) {
        controller.customInfoViewControllers = hosting.map { [$0] } ?? []
    }

    private static func makeFeedMenuItems(
        feeds: [ChannelFeed],
        selectedFeedID: String?,
        onSelectFeed: @escaping @MainActor (String?) -> Void
    ) -> [UIMenuElement] {
        guard feeds.count > 1 else {
            return []
        }

        let automatic = UIAction(
            title: String(localized: "player.feed.auto"),
            state: selectedFeedID == nil ? .on : .off
        ) { _ in
            Task { @MainActor in
                onSelectFeed(nil)
            }
        }

        let feedActions = feeds.map { feed in
            UIAction(
                title: feed.displayName,
                state: selectedFeedID == feed.id ? .on : .off
            ) { _ in
                Task { @MainActor in
                    onSelectFeed(feed.id)
                }
            }
        }

        let menu = UIMenu(
            title: String(localized: "player.feed"),
            children: [automatic] + feedActions
        )
        return [menu]
    }

    private static func makeSleepTimerMenuItems(
        selectedMinutes: Int?,
        onSelect: @escaping @MainActor (Int?) -> Void
    ) -> [UIMenuElement] {
        let options: [(String, Int?)] = [
            (String(localized: "player.sleepTimer.off"), nil),
            (String(localized: "player.sleepTimer.15"), 15),
            (String(localized: "player.sleepTimer.30"), 30),
            (String(localized: "player.sleepTimer.60"), 60)
        ]
        let actions = options.map { title, minutes in
            UIAction(
                title: title,
                state: selectedMinutes == minutes ? .on : .off
            ) { _ in
                Task { @MainActor in onSelect(minutes) }
            }
        }
        return [UIMenu(title: String(localized: "player.sleepTimer"), children: actions)]
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var lastRefreshID = 0
        var onPictureInPictureWillStart: @MainActor () -> Void
        var onPlayerDismissRequested: @MainActor () -> Void
        var onPictureInPictureDidStart: @MainActor () -> Void
        var onPictureInPictureStartFailed: @MainActor () -> Void
        var onPictureInPictureDidStop: @MainActor () -> Void
        var onPictureInPictureRestoreRequested: @MainActor (@escaping (Bool) -> Void) -> Void
        var infoHostingController: UIHostingController<AnyView>?
        var isInfoPanelInstalled = false
        var didDismissInfoPanelForSleepTimer = false

        init(
            onPictureInPictureWillStart: @escaping @MainActor () -> Void,
            onPlayerDismissRequested: @escaping @MainActor () -> Void,
            onPictureInPictureDidStart: @escaping @MainActor () -> Void,
            onPictureInPictureStartFailed: @escaping @MainActor () -> Void,
            onPictureInPictureDidStop: @escaping @MainActor () -> Void,
            onPictureInPictureRestoreRequested:
                @escaping @MainActor (@escaping (Bool) -> Void) -> Void
        ) {
            self.onPictureInPictureWillStart = onPictureInPictureWillStart
            self.onPlayerDismissRequested = onPlayerDismissRequested
            self.onPictureInPictureDidStart = onPictureInPictureDidStart
            self.onPictureInPictureStartFailed = onPictureInPictureStartFailed
            self.onPictureInPictureDidStop = onPictureInPictureDidStop
            self.onPictureInPictureRestoreRequested =
                onPictureInPictureRestoreRequested
        }

        func dismissInfoPanel(_ controller: AVPlayerViewController) {
            if let presented = controller.presentedViewController {
                presented.dismiss(animated: true)
                return
            }
            if isInfoPanelInstalled {
                // The custom Info tab can be hosted inside AVKit instead of
                // appearing as a presented view controller. Removing the tab
                // is the reliable fallback that also releases its focus.
                controller.customInfoViewControllers = []
                isInfoPanelInstalled = false
            }
        }

        func playerViewControllerWillStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            pictureInPictureLogger.info("delegate.willStart")
            let callback = onPictureInPictureWillStart
            MainActor.assumeIsolated {
                callback()
            }
        }

        func playerViewControllerShouldDismiss(
            _ playerViewController: AVPlayerViewController
        ) -> Bool {
            pictureInPictureLogger.info("delegate.dismissRequested")
            let callback = onPlayerDismissRequested
            MainActor.assumeIsolated {
                callback()
            }
            return false
        }

        func playerViewControllerDidStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            pictureInPictureLogger.info("delegate.didStart")
            let callback = onPictureInPictureDidStart
            MainActor.assumeIsolated {
                callback()
            }
        }

        func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
            _ playerViewController: AVPlayerViewController
        ) -> Bool {
            pictureInPictureLogger.info("delegate.autoDismiss=false managedByPresenter")
            return false
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            failedToStartPictureInPictureWithError error: Error
        ) {
            pictureInPictureLogger.error("delegate.startFailed")
            let callback = onPictureInPictureStartFailed
            MainActor.assumeIsolated {
                callback()
            }
        }

        func playerViewControllerDidStopPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            pictureInPictureLogger.info("delegate.didStop")
            let callback = onPictureInPictureDidStop
            MainActor.assumeIsolated {
                callback()
            }
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            pictureInPictureLogger.info("delegate.restoreRequested")
            let restore = onPictureInPictureRestoreRequested
            let completion = PictureInPictureRestoreCompletion(completionHandler)
            MainActor.assumeIsolated {
                restore(completion.callAsFunction)
            }
        }
    }
}
#endif
