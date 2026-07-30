import AVKit
import SwiftUI

#if os(iOS) || os(macOS)
struct PlatformPlayerView: View {
    let player: AVPlayer

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
    }
}
#elseif os(tvOS)
struct PlatformPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

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
        #endif
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}
#endif
