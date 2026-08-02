import AVKit
import SwiftUI

#if os(macOS)
struct PlatformPlayerView: NSViewRepresentable {
    let player: AVPlayer
    let feeds: [ChannelFeed]
    let selectedFeedID: String?
    let onSelectFeed: @MainActor (String?) -> Void
    let infoView: AnyView?

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
    }
}
#elseif os(iOS)
struct PlatformPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let feeds: [ChannelFeed]
    let selectedFeedID: String?
    let onSelectFeed: @MainActor (String?) -> Void
    let infoView: AnyView?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        controller.allowsPictureInPicturePlayback = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }

    final class Coordinator {}
}
#elseif os(tvOS)
struct PlatformPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let feeds: [ChannelFeed]
    let selectedFeedID: String?
    let onSelectFeed: @MainActor (String?) -> Void
    let infoView: AnyView?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.playbackControlsIncludeTransportBar = true
        controller.transportBarIncludesTitleView = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
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
                newHosting.view.backgroundColor = .black
                context.coordinator.infoHostingController = newHosting
                return newHosting
            }()
            controller.customInfoViewControllers = [hosting]
        } else {
            controller.customInfoViewControllers = []
        }
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

    final class Coordinator {
        var infoHostingController: UIHostingController<AnyView>?
    }
}
#endif
