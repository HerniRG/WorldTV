#if os(iOS) || os(tvOS)
import OSLog
import SwiftUI
import UIKit

private let playerPresentationLogger = Logger(
    subsystem: "com.hernirg.worldtv",
    category: "PlayerPresentation"
)

struct NativePlayerPresenter: UIViewControllerRepresentable {
    @Binding var presentation: PlayerPresentation?
    let container: AppContainer

    func makeUIViewController(context: Context) -> PresenterViewController {
        PresenterViewController()
    }

    func updateUIViewController(
        _ controller: PresenterViewController,
        context: Context
    ) {
        controller.update(
            presentation: presentation,
            container: container,
            onDismiss: { dismissedID in
                guard self.presentation?.id == dismissedID else {
                    return
                }
                self.presentation = nil
            }
        )
    }

    @MainActor
    final class PresenterViewController: UIViewController,
        UIAdaptivePresentationControllerDelegate {
        private var stateMachine = PlayerPresentationStateMachine()
        private var activePresentationID: UUID?
        private var activePlayerViewModel: PlayerViewModel?
        private var presentedPlayer: UIViewController?
        private weak var presentationHost: UIViewController?
        private weak var managedPresentationController: UIPresentationController?
        private weak var pictureInPictureDismissalController: UIPresentationController?
        private var isDetachedForPictureInPicture = false
        private var pendingPresentation: PlayerPresentation?
        private var pendingContainer: AppContainer?
        private var pendingRestoreCompletion: ((Bool) -> Void)?
        private var onDismiss: (@MainActor (UUID) -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            view.backgroundColor = .clear
            presentPendingPlayerIfPossible()
        }

        func update(
            presentation: PlayerPresentation?,
            container: AppContainer,
            onDismiss: @escaping @MainActor (UUID) -> Void
        ) {
            pendingPresentation = presentation
            pendingContainer = container
            self.onDismiss = onDismiss

            guard let presentation else {
                if let activePresentationID {
                    requestFinalDismissal(for: activePresentationID)
                }
                return
            }

            if let activePresentationID, activePresentationID != presentation.id {
                requestFinalDismissal(for: activePresentationID, clearPending: false)
                return
            }

            presentPendingPlayerIfPossible()
        }

        private func presentPendingPlayerIfPossible() {
            guard
                stateMachine.state == .idle,
                viewIfLoaded?.window != nil,
                let presentation = pendingPresentation,
                let container = pendingContainer,
                let host = presentationHostController,
                host.presentedViewController == nil
            else {
                return
            }

            let presentationID = presentation.id
            let viewModel = PlayerViewModel(
                channelID: presentation.channelID,
                resolveSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched,
                initialFeedID: presentation.feedID
            )
            let player = PlayerView(
                viewModel: viewModel,
                closePresentation: { [weak self] in
                    self?.requestFinalDismissal(for: presentationID)
                },
                onPictureInPictureWillStart: { [weak self] in
                    self?.pictureInPictureWillStart(for: presentationID)
                },
                onPictureInPictureDidStart: { [weak self] in
                    self?.pictureInPictureDidStart(for: presentationID)
                },
                onPictureInPictureStartFailed: { [weak self] in
                    self?.pictureInPictureStartFailed(for: presentationID)
                },
                onPictureInPictureDidStop: { [weak self] in
                    self?.pictureInPictureDidStop(for: presentationID)
                },
                restorePresentation: { [weak self] completion in
                    guard let self else {
                        completion(false)
                        return
                    }
                    self.restorePresentation(
                        for: presentationID,
                        completion: completion
                    )
                },
                preservesPlaybackOnDisappear: { [weak self] in
                    self?.stateMachine.preservesPlaybackWhenViewDisappears ?? false
                }
            )
            let hosting = UIHostingController(rootView: player)
            hosting.modalPresentationStyle = .fullScreen
            #if os(tvOS)
            hosting.restoresFocusAfterTransition = true
            host.restoresFocusAfterTransition = true
            #endif

            activePresentationID = presentationID
            activePlayerViewModel = viewModel
            presentedPlayer = hosting
            presentationHost = host
            _ = stateMachine.didPresent()
            logState("present")

            host.present(hosting, animated: false) { [weak self, weak hosting] in
                guard let self, let hosting else {
                    return
                }
                self.installPresentationDelegate(for: hosting)
            }
        }

        private func pictureInPictureWillStart(for presentationID: UUID) {
            guard isCurrent(presentationID), stateMachine.willStartPictureInPicture() else {
                return
            }
            logState("pipWillStart")
        }

        private func pictureInPictureDidStart(for presentationID: UUID) {
            guard isCurrent(presentationID), stateMachine.didStartPictureInPicture() else {
                return
            }
            logState("pipDidStart")
            dismissPlayerForPictureInPicture()
        }

        private func pictureInPictureStartFailed(for presentationID: UUID) {
            guard isCurrent(presentationID), stateMachine.pictureInPictureStartFailed() else {
                return
            }
            logState("pipStartFailed")
        }

        private func dismissPlayerForPictureInPicture() {
            guard let player = presentedPlayer else {
                return
            }
            pictureInPictureDismissalController = player.presentationController
            player.dismiss(animated: false) { [weak self] in
                guard let self else {
                    return
                }
                self.isDetachedForPictureInPicture = true
                if self.stateMachine.state == .restoring {
                    self.restorePlayerIfPossible()
                }
            }
        }

        private func restorePresentation(
            for presentationID: UUID,
            completion: @escaping (Bool) -> Void
        ) {
            guard isCurrent(presentationID) else {
                completion(false)
                return
            }
            guard pendingRestoreCompletion == nil else {
                completion(false)
                return
            }
            guard stateMachine.beginRestoration() else {
                completion(stateMachine.state == .presented)
                return
            }

            pendingRestoreCompletion = completion
            logState("restoreRequested")
            if isDetachedForPictureInPicture {
                restorePlayerIfPossible()
            }
        }

        private func restorePlayerIfPossible() {
            guard
                stateMachine.state == .restoring,
                let player = presentedPlayer,
                player.presentingViewController == nil,
                let host = presentationHostController,
                host.presentedViewController == nil
            else {
                failRestorationIfPresenterIsUnavailable()
                return
            }

            host.present(player, animated: false) { [weak self, weak player] in
                guard let self, let player else {
                    return
                }
                self.isDetachedForPictureInPicture = false
                self.installPresentationDelegate(for: player)
                guard self.stateMachine.didRestore() else {
                    self.finishRestoreRequest(false)
                    return
                }
                self.logState("restoreCompleted")
                self.finishRestoreRequest(true)
            }
        }

        private func failRestorationIfPresenterIsUnavailable() {
            _ = stateMachine.restorationFailed()
            logState("restoreFailed")
            finishRestoreRequest(false)
        }

        private func finishRestoreRequest(_ restored: Bool) {
            let completion = pendingRestoreCompletion
            pendingRestoreCompletion = nil
            completion?(restored)
        }

        private func pictureInPictureDidStop(for presentationID: UUID) {
            guard isCurrent(presentationID) else {
                return
            }
            switch stateMachine.state {
            case .presented, .restoring, .dismissing, .idle:
                // Restoration or final dismissal owns the transition. A late
                // AVKit didStop callback must not tear down the visible player.
                return
            case .enteringPiP, .inPiP:
                requestFinalDismissal(for: presentationID)
            }
        }

        private func requestFinalDismissal(
            for presentationID: UUID,
            clearPending: Bool = true
        ) {
            guard isCurrent(presentationID), stateMachine.beginDismissal() else {
                return
            }
            if clearPending, pendingPresentation?.id == presentationID {
                pendingPresentation = nil
            }
            logState("dismiss")
            finishRestoreRequest(false)
            activePlayerViewModel?.stop()

            guard let player = presentedPlayer, player.presentingViewController != nil else {
                completeFinalDismissal(for: presentationID)
                return
            }
            player.dismiss(animated: false) { [weak self] in
                self?.completeFinalDismissal(for: presentationID)
            }
        }

        private func completeFinalDismissal(for presentationID: UUID) {
            guard isCurrent(presentationID), stateMachine.didDismiss() else {
                return
            }
            activePlayerViewModel = nil
            presentedPlayer = nil
            managedPresentationController = nil
            pictureInPictureDismissalController = nil
            presentationHost = nil
            activePresentationID = nil
            isDetachedForPictureInPicture = false
            logState("dismissCompleted")
            onDismiss?(presentationID)
            presentPendingPlayerIfPossible()
        }

        private func installPresentationDelegate(for player: UIViewController) {
            let presentationController = player.presentationController
            presentationController?.delegate = self
            managedPresentationController = presentationController
        }

        func presentationControllerWillDismiss(
            _ presentationController: UIPresentationController
        ) {
            guard
                presentationController === managedPresentationController,
                let activePresentationID,
                !stateMachine.preservesPlaybackWhenViewDisappears
            else {
                return
            }
            if stateMachine.beginDismissal() {
                if pendingPresentation?.id == activePresentationID {
                    pendingPresentation = nil
                }
                finishRestoreRequest(false)
                activePlayerViewModel?.stop()
                logState("nativeDismiss")
            }
        }

        func presentationControllerDidDismiss(
            _ presentationController: UIPresentationController
        ) {
            if presentationController === pictureInPictureDismissalController {
                pictureInPictureDismissalController = nil
                return
            }
            guard
                presentationController === managedPresentationController,
                let activePresentationID
            else {
                return
            }
            if stateMachine.state != .dismissing {
                _ = stateMachine.beginDismissal()
                activePlayerViewModel?.stop()
            }
            completeFinalDismissal(for: activePresentationID)
        }

        private func isCurrent(_ presentationID: UUID) -> Bool {
            activePresentationID == presentationID
        }

        private var presentationHostController: UIViewController? {
            if let presentationHost, presentationHost.viewIfLoaded?.window != nil {
                return presentationHost
            }
            var host: UIViewController = self
            while let parent = host.parent {
                host = parent
            }
            return host.viewIfLoaded?.window == nil ? nil : host
        }

        private func logState(_ event: StaticString) {
            playerPresentationLogger.info(
                "event=\(event) state=\(self.stateMachine.state.rawValue, privacy: .public)"
            )
        }
    }
}
#endif
