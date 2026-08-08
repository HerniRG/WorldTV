import AVFoundation
import Foundation

@MainActor
final class AudioSessionCoordinator {
    #if os(iOS) || os(tvOS)
    private let session = AVAudioSession.sharedInstance()
    private var didConfigure = false
    private var onRouteChange: (@MainActor () -> Void)?

    func activate(
        player: AVPlayer,
        onRouteChange: (@MainActor () -> Void)? = nil
    ) {
        self.onRouteChange = onRouteChange
        guard !didConfigure else { return }
        didConfigure = true

        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)

        #if os(iOS)
        observeInterruptions(player: player)
        #endif
    }

    #if os(iOS)
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    #endif

    #if os(iOS)
    private func observeInterruptions(player: AVPlayer) {
        guard interruptionObserver == nil else { return }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak player] notification in
            guard
                let userInfo = notification.userInfo,
                let typeValue = userInfo[
                    AVAudioSessionInterruptionTypeKey
                ] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else {
                return
            }

            switch type {
            case .began:
                player?.pause()
            case .ended:
                guard
                    let optionsValue = userInfo[
                        AVAudioSessionInterruptionOptionKey
                    ] as? UInt
                else {
                    return
                }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    player?.play()
                }
            default:
                break
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self, weak player] notification in
            guard
                let reasonValue = notification.userInfo?[
                    AVAudioSessionRouteChangeReasonKey
                ] as? UInt,
                let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
            else {
                return
            }

            if reason == .oldDeviceUnavailable {
                player?.pause()
            }
            Task { @MainActor [weak self] in
                self?.onRouteChange?()
            }
        }
    }
    #endif
    #else
    func activate(
        player: AVPlayer,
        onRouteChange: (@MainActor () -> Void)? = nil
    ) {}
    #endif

}
