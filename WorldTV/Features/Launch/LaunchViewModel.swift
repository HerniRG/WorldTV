import Foundation
import Observation

@Observable
@MainActor
final class LaunchViewModel {
    private(set) var state: Loadable<CatalogSummary> = .idle

    private let loadCatalogSummary: LoadCatalogSummaryUseCase
    private var loadTask: Task<Void, Never>?

    init(loadCatalogSummary: LoadCatalogSummaryUseCase) {
        self.loadCatalogSummary = loadCatalogSummary
    }

    func loadIfNeeded() {
        guard case .idle = state else {
            return
        }
        load()
    }

    func retry() {
        load()
    }

    private func load() {
        loadTask?.cancel()
        state = .loading

        loadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let summary = try await loadCatalogSummary.execute()
                guard !Task.isCancelled else {
                    return
                }
                state = summary.channelCount == 0 ? .empty : .loaded(summary)
            } catch is CancellationError {
                return
            } catch {
                state = .failed(.catalogUnavailable)
            }
        }
    }
}
