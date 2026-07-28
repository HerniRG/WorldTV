import SwiftUI

struct ContentView: View {
    @State private var homeViewModel: HomeViewModel
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _homeViewModel = State(
            initialValue: HomeViewModel(loadHomeContent: container.loadHomeContent)
        )
    }

    var body: some View {
        #if os(tvOS)
        TVRootView(homeViewModel: homeViewModel, container: container)
        #elseif os(macOS)
        MacRootView(homeViewModel: homeViewModel, container: container)
        #else
        IOSRootView(homeViewModel: homeViewModel, container: container)
        #endif
    }
}
