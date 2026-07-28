import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var state: Loadable<HomeContent> = .idle

    private let loadHomeContent: LoadHomeContentUseCase
    private var loadTask: Task<Void, Never>?

    init(loadHomeContent: LoadHomeContentUseCase) {
        self.loadHomeContent = loadHomeContent
    }

    func loadIfNeeded() {
        guard case .idle = state else {
            return
        }
        load(forceRefresh: false)
    }

    func refresh() {
        load(forceRefresh: true)
    }

    func retry() {
        load(forceRefresh: false)
    }

    func reloadVisibleContent() {
        guard case .loaded = state else {
            return
        }
        load(forceRefresh: false, showsLoading: false)
    }

    private func load(forceRefresh: Bool, showsLoading: Bool = true) {
        loadTask?.cancel()
        if showsLoading {
            state = .loading
        }
        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let content = try await loadHomeContent.execute(forceRefresh: forceRefresh)
                guard !Task.isCancelled else {
                    return
                }
                state = content.summary.channelCount == 0 ? .empty : .loaded(content)
            } catch is CancellationError {
                return
            } catch {
                state = .failed(.catalogUnavailable)
            }
        }
    }
}
