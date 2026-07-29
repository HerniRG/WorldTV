import AVKit
import SwiftUI

#if os(macOS)
struct PlatformPlayerView: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
    }
}
#else
struct PlatformPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    #if os(tvOS)
    @Binding var transportBarIsVisible: Bool
    let hidePlaybackControlsRequest: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(transportBarIsVisible: $transportBarIsVisible)
    }
    #endif

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        #if os(tvOS)
        controller.appliesPreferredDisplayCriteriaAutomatically = true
        controller.playbackControlsIncludeTransportBar = true
        controller.transportBarIncludesTitleView = false
        controller.delegate = context.coordinator
        #endif
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
        #if os(tvOS)
        context.coordinator.transportBarIsVisible = $transportBarIsVisible
        guard
            context.coordinator.lastHidePlaybackControlsRequest
                != hidePlaybackControlsRequest
        else {
            return
        }

        context.coordinator.lastHidePlaybackControlsRequest =
            hidePlaybackControlsRequest
        controller.showsPlaybackControls = false
        let coordinator = context.coordinator
        Task { @MainActor [weak controller] in
            coordinator.transportBarIsVisible.wrappedValue = false
            await Task.yield()
            controller?.showsPlaybackControls = true
        }
        #endif
    }

    #if os(tvOS)
    @MainActor
    final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        var transportBarIsVisible: Binding<Bool>
        var lastHidePlaybackControlsRequest = 0

        init(transportBarIsVisible: Binding<Bool>) {
            self.transportBarIsVisible = transportBarIsVisible
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willTransitionToVisibilityOfTransportBar visible: Bool,
            with coordinator:
                any AVPlayerViewControllerAnimationCoordinator
        ) {
            transportBarIsVisible.wrappedValue = visible
        }
    }
    #endif
}
#endif
