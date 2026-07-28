#if os(macOS)
import SwiftUI

struct MacRootView: View {
    @SceneStorage("mac.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue

    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: selection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 240)
        } detail: {
            AppSectionNavigationStack(
                section: selection.wrappedValue ?? .home,
                homeViewModel: homeViewModel,
                container: container
            )
        }
    }

    private var selection: Binding<AppSection?> {
        Binding(
            get: { AppSection(rawValue: selectedSectionRawValue) ?? .home },
            set: { selectedSectionRawValue = ($0 ?? .home).rawValue }
        )
    }
}
#endif
