import AVFoundation
import Foundation

@MainActor
final class AudioSessionCoordinator {
    #if os(iOS)
    private let session = AVAudioSession.sharedInstance()
    private var interruptionObserver: NSObjectProtocol?
    private var didConfigure = false

    func activate(player: AVPlayer) {
        guard !didConfigure else { return }
        didConfigure = true

        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        observeInterruptions(player: player)
    }
    #else
    func activate(player: AVPlayer) {}
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
    }
    #endif
}
