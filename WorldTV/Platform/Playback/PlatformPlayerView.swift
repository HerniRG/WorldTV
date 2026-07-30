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
    let onDismiss: (@MainActor () -> Void)?

    init(
        player: AVPlayer,
        onDismiss: (@MainActor () -> Void)? = nil
    ) {
        self.player = player
        self.onDismiss = onDismiss
    }

    func makeUIViewController(context: Context) -> NativePlayerHost {
        NativePlayerHost()
    }

    func updateUIViewController(_ host: NativePlayerHost, context: Context) {
        host.update(player: player, onDismiss: onDismiss)
    }

    static func dismantleUIViewController(
        _ host: NativePlayerHost,
        coordinator: ()
    ) {
        host.dismissPlayer()
    }
}

@MainActor
final class NativePlayerHost: UIViewController {
    private var player: AVPlayer?
    private var onDismiss: (@MainActor () -> Void)?
    private var playerController: NativePlayerController?
    private var currentItemObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    func update(
        player: AVPlayer,
        onDismiss: (@MainActor () -> Void)?
    ) {
        self.player = player
        self.onDismiss = onDismiss

        currentItemObservation = player.observe(
            \.currentItem,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.presentPlayer()
            }
        }

        if let playerController {
            playerController.player = player
            playerController.onDismiss = onDismiss
        } else {
            presentPlayer()
        }
    }

    func dismissPlayer() {
        currentItemObservation = nil
        guard let playerController else { return }
        playerController.onDismiss = nil
        playerController.dismiss(animated: false)
        self.playerController = nil
    }

    private func presentPlayer() {
        guard
            playerController == nil,
            presentedViewController == nil,
            let player,
            player.currentItem != nil
        else {
            return
        }

        let controller = NativePlayerController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        controller.modalPresentationStyle = .fullScreen
        controller.onDismiss = onDismiss
        playerController = controller
        present(controller, animated: false)
    }
}

@MainActor
final class NativePlayerController: AVPlayerViewController {
    var onDismiss: (@MainActor () -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed else { return }
        let callback = onDismiss
        onDismiss = nil
        callback?()
    }
}
#endif
