import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var homeViewModel: HomeViewModel
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _homeViewModel = State(
            initialValue: HomeViewModel(loadHomeContent: container.loadHomeContent)
        )
    }

    var body: some View {
        Group {
            #if os(tvOS)
            TVRootView(homeViewModel: homeViewModel, container: container)
            #else
            AppRootView(homeViewModel: homeViewModel, container: container)
            #endif
        }
        .task {
            await container.synchronizePreferences()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await container.favoritesStore.reload()
                await container.synchronizePreferences()
                homeViewModel.reloadVisibleContent()
                NotificationCenter.default.post(name: .playlistSourcesDidChange, object: nil)
            }
        }
    }
}
