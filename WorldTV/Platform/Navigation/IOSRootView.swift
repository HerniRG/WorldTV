#if os(iOS)
import SwiftUI

struct IOSRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SceneStorage("ios.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    @State private var sidebarSelection: AppSection? = .home
    @State private var presentedPlayer: IOSPresentedPlayer?

    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitRoot
            } else {
                tabRoot
            }
        }
        .environment(\.playChannel) { channelID in
            presentedPlayer = IOSPresentedPlayer(channelID: channelID)
        }
        .fullScreenCover(item: $presentedPlayer) { presentation in
            PlayerView(
                channelID: presentation.channelID,
                resolveSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched
            )
            .id(presentation.id)
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

private struct IOSPresentedPlayer: Identifiable {
    let channelID: String

    var id: String {
        channelID
    }
}
#endif
