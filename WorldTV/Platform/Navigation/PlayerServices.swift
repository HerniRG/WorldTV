import SwiftUI

struct PlayerServices: Sendable {
    let resolveSources: ResolvePlayableStreamUseCase
    let recordRecentlyWatched: RecordRecentlyWatchedUseCase
}

private struct PlayerServicesKey: EnvironmentKey {
    static let defaultValue: PlayerServices? = nil
}

extension EnvironmentValues {
    var playerServices: PlayerServices? {
        get { self[PlayerServicesKey.self] }
        set { self[PlayerServicesKey.self] = newValue }
    }
}
