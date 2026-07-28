#if os(iOS)
import SwiftUI

struct IOSRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SceneStorage("ios.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    @State private var sidebarSelection: AppSection? = .home

    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
        if horizontalSizeClass == .regular {
            splitRoot
        } else {
            tabRoot
        }
    }

    private var selectedSection: Binding<AppSection> {
        Binding(
            get: { AppSection(rawValue: selectedSectionRawValue) ?? .home },
            set: { selectedSectionRawValue = $0.rawValue }
        )
    }

    private var tabRoot: some View {
        TabView(selection: selectedSection) {
            ForEach(AppSection.allCases) { section in
                AppSectionNavigationStack(
                    section: section,
                    homeViewModel: homeViewModel,
                    container: container
                )
                .tabItem {
                    Label(
                        LocalizedStringKey(section.localizationKey),
                        systemImage: section.systemImage
                    )
                }
                .tag(section)
            }
        }
    }

    private var splitRoot: some View {
        NavigationSplitView {
            AppSidebar(selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            AppSectionNavigationStack(
                section: sidebarSelection ?? .home,
                homeViewModel: homeViewModel,
                container: container
            )
        }
    }
}
#endif
