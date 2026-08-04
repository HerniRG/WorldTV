import Foundation
import Observation

@Observable
@MainActor
class LoadableViewModel<Value: Sendable> {
    private(set) var state: Loadable<Value> = .idle

    @ObservationIgnored
    private let loadValue: @Sendable (_ forceRefresh: Bool) async throws -> Value?

    @ObservationIgnored
    private var loadTask: Task<Void, Never>?

    init(load: @escaping @Sendable (_ forceRefresh: Bool) async throws -> Value?) {
        self.loadValue = load
    }

    func loadIfNeeded() async {
        guard case .idle = state else {
            return
        }
        await reload()
    }

    func reload(forceRefresh: Bool = false) async {
        await perform(forceRefresh: forceRefresh, showsLoading: true)
    }

    func reloadSilently() async {
        await perform(forceRefresh: false, showsLoading: false)
    }

    func retry() {
        state = .idle
    }

    private func perform(forceRefresh: Bool, showsLoading: Bool) async {
        loadTask?.cancel()
        // A silent refresh may be used during the first appearance of a screen.
        // It must still leave idle visible as loading, otherwise a second task
        // can start and the UI may briefly show the empty state before data arrives.
        if showsLoading || state.isIdle {
            state = .loading
        }
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let value = try await loadValue(forceRefresh)
                guard !Task.isCancelled else {
                    return
                }
                state = value.map { .loaded($0) } ?? .empty
            } catch is CancellationError {
                return
            } catch {
                state = .failed(.catalogUnavailable)
            }
        }
        _ = await loadTask?.value
    }
}

private extension Loadable {
    var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }
}
