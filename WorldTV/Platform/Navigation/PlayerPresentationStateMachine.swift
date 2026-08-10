import Foundation

struct PlayerPresentation: Identifiable, Equatable {
    let id = UUID()
    let channelID: String
    let feedID: String?

    init(channelID: String, feedID: String? = nil) {
        self.channelID = channelID
        self.feedID = feedID
    }

    init?(playURL url: URL) {
        guard url.scheme == "worldtv", url.host == "play" else {
            return nil
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let channelID = components.first, !channelID.isEmpty else {
            return nil
        }
        self.init(channelID: channelID)
    }
}

enum PlayerPresentationState: String, Equatable, Sendable {
    case idle
    case presented
    case enteringPiP
    case inPiP
    case restoring
    case dismissing
}

struct PlayerPresentationStateMachine: Equatable, Sendable {
    private(set) var state: PlayerPresentationState = .idle

    @discardableResult
    mutating func didPresent() -> Bool {
        transition(from: [.idle], to: .presented)
    }

    @discardableResult
    mutating func willStartPictureInPicture() -> Bool {
        transition(from: [.presented], to: .enteringPiP)
    }

    @discardableResult
    mutating func didStartPictureInPicture() -> Bool {
        transition(from: [.enteringPiP], to: .inPiP)
    }

    @discardableResult
    mutating func pictureInPictureStartFailed() -> Bool {
        transition(from: [.enteringPiP], to: .presented)
    }

    @discardableResult
    mutating func beginRestoration() -> Bool {
        transition(from: [.inPiP], to: .restoring)
    }

    @discardableResult
    mutating func didRestore() -> Bool {
        transition(from: [.restoring], to: .presented)
    }

    @discardableResult
    mutating func restorationFailed() -> Bool {
        transition(from: [.restoring], to: .inPiP)
    }

    @discardableResult
    mutating func beginDismissal() -> Bool {
        transition(from: [.presented, .enteringPiP, .inPiP, .restoring], to: .dismissing)
    }

    @discardableResult
    mutating func didDismiss() -> Bool {
        transition(from: [.dismissing], to: .idle)
    }

    var preservesPlaybackWhenViewDisappears: Bool {
        switch state {
        case .enteringPiP, .inPiP, .restoring:
            true
        case .idle, .presented, .dismissing:
            false
        }
    }

    private mutating func transition(
        from allowedStates: Set<PlayerPresentationState>,
        to newState: PlayerPresentationState
    ) -> Bool {
        guard allowedStates.contains(state) else {
            return false
        }
        state = newState
        return true
    }
}
