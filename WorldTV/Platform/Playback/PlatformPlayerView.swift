import AVKit
import SwiftUI

#if os(macOS)
struct PlatformPlayerView: NSViewRepresentable {
    let player: AVPlayer
    let refreshID: Int
    let feeds: [ChannelFeed]
    let selectedFeedID: String?
    let onSelectFeed: @MainActor (String?) -> Void
    let onPictureInPictureChanged: @MainActor (Bool) -> Void
    let infoView: AnyView?

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
    let onPictureInPictureChanged: @MainActor (Bool) -> Void
    let infoView: AnyView?

    func makeCoordinator() -> Coordinator {
        Coordinator(onPictureInPictureChanged: onPictureInPictureChanged)
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
        context.coordinator.onPictureInPictureChanged = onPictureInPictureChanged
        controller.player = player
        if context.coordinator.lastRefreshID != refreshID {
            context.coordinator.lastRefreshID = refreshID
            controller.player = nil
            controller.player = player
        }
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var lastRefreshID = 0
        var onPictureInPictureChanged: @MainActor (Bool) -> Void

        init(onPictureInPictureChanged: @escaping @MainActor (Bool) -> Void) {
            self.onPictureInPictureChanged = onPictureInPictureChanged
        }

        func playerViewControllerDidStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            let callback = onPictureInPictureChanged
            MainActor.assumeIsolated {
                callback(true)
            }
        }

        func playerViewControllerDidStopPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            let callback = onPictureInPictureChanged
            MainActor.assumeIsolated {
                callback(false)
            }
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            let callback = onPictureInPictureChanged
            MainActor.assumeIsolated {
                callback(false)
            }
            completionHandler(true)
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
    let onPictureInPictureChanged: @MainActor (Bool) -> Void
    let infoView: AnyView?

    func makeCoordinator() -> Coordinator {
        Coordinator(onPictureInPictureChanged: onPictureInPictureChanged)
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
        context.coordinator.onPictureInPictureChanged = onPictureInPictureChanged
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
        )
        configureInfoPanel(controller, context: context)
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
        // customInfoViewController is deprecated since tvOS 15, but its
        // replacement (customInfoViewControllers) re-measures the panel on
        // every reopen and causes the vertical placement bug we work around.
        // KVC sets the property without a deprecation warning.
        controller.setValue(hosting, forKey: "customInfoViewController")
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

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var lastRefreshID = 0
        var onPictureInPictureChanged: @MainActor (Bool) -> Void
        var infoHostingController: UIHostingController<AnyView>?
        var isInfoPanelInstalled = false

        init(onPictureInPictureChanged: @escaping @MainActor (Bool) -> Void) {
            self.onPictureInPictureChanged = onPictureInPictureChanged
        }

        func playerViewControllerDidStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            let callback = onPictureInPictureChanged
            MainActor.assumeIsolated {
                callback(true)
            }
        }

        func playerViewControllerDidStopPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            let callback = onPictureInPictureChanged
            MainActor.assumeIsolated {
                callback(false)
            }
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            let callback = onPictureInPictureChanged
            MainActor.assumeIsolated {
                callback(false)
            }
            completionHandler(true)
        }
    }
}
#endif
