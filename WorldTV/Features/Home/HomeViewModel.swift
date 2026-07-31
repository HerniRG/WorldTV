import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel: LoadableViewModel<HomeContent> {
    private let loadHomeContent: LoadHomeContentUseCase

    init(loadHomeContent: LoadHomeContentUseCase) {
        self.loadHomeContent = loadHomeContent
        super.init(load: { [loadHomeContent] forceRefresh in
            let content = try await loadHomeContent.execute(forceRefresh: forceRefresh)
            return content.summary.channelCount == 0 ? nil : content
        })
    }

    func refresh() {
        Task {
            await super.reload(forceRefresh: true)
        }
    }

    override func retry() {
        Task {
            await super.reload()
        }
    }

    func reloadVisibleContent() {
        guard case .loaded = state else {
            return
        }
        Task {
            await super.reloadSilently()
        }
    }
}
