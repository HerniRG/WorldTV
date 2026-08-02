import Foundation
import Observation

@Observable
@MainActor
final class PlayerOverlayVisibility {
    private(set) var isVisible = true

    private let hideDelay: Duration
    private var isPlaying = false
    private var hideTask: Task<Void, Never>?

    init(hideDelay: Duration = .seconds(3.5)) {
        self.hideDelay = hideDelay
    }

    func playbackStateDidChange(_ state: PlaybackState) {
        switch state {
        case .idle, .resolving, .preparing, .buffering, .paused, .failed, .ended:
            cancelHide()
            isPlaying = false
            setVisible(true)
        case .playing:
            isPlaying = true
            scheduleHideIfNeeded()
        }
    }

    func userInteracted() {
        setVisible(true)
        scheduleHideIfNeeded()
    }

    func cancel() {
        cancelHide()
    }

    private func setVisible(_ visible: Bool) {
        guard isVisible != visible else {
            return
        }
        isVisible = visible
    }

    private func scheduleHideIfNeeded() {
        guard isPlaying else {
            return
        }
        hideTask?.cancel()
        hideTask = Task { [weak self, hideDelay] in
            try? await Task.sleep(for: hideDelay)
            guard !Task.isCancelled, let self else {
                return
            }
            self.setVisible(false)
        }
    }

    private func cancelHide() {
        hideTask?.cancel()
        hideTask = nil
    }
}
