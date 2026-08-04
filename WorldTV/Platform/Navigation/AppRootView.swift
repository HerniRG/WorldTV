#if os(iOS) || os(macOS)
import SwiftUI

struct AppRootView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    #if os(macOS)
    @SceneStorage("mac.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    #else
    @SceneStorage("ios.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    #endif
    @State private var presentedPlayer: PresentedPlayer?
    @State private var navigationResetRequest = 0

    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
        root
            .environment(\.playChannel) { channelID in
                presentedPlayer = PresentedPlayer(channelID: channelID)
            }
            .environment(\.playChannelWithInitialFeed) { channelID, feedID in
                presentedPlayer = PresentedPlayer(channelID: channelID, feedID: feedID)
            }
            .playerPresentation($presentedPlayer, container: container)
            .onChange(of: selectedSectionRawValue) { _, _ in
                navigationResetRequest += 1
            }
    }

    @ViewBuilder
    private var root: some View {
        #if os(macOS)
        NavigationSplitView {
            AppSidebar(selection: sidebarSelection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 240)
        } detail: {
            AppSectionNavigationStack(
                section: sidebarSelection.wrappedValue ?? .home,
                homeViewModel: homeViewModel,
                container: container,
                navigationResetRequest: navigationResetRequest
            )
            .id("\(sidebarSelection.wrappedValue?.rawValue ?? AppSection.home.rawValue)-\(navigationResetRequest)")
        }
        #else
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                AppSidebar(selection: sidebarSelection)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 280)
            } detail: {
                AppSectionNavigationStack(
                    section: sidebarSelection.wrappedValue ?? .home,
                    homeViewModel: homeViewModel,
                    container: container,
                    navigationResetRequest: navigationResetRequest
                )
                .id("\(sidebarSelection.wrappedValue?.rawValue ?? AppSection.home.rawValue)-\(navigationResetRequest)")
            }
        } else {
            TabView(selection: selectedSection) {
                ForEach(AppSection.allCases) { section in
                    AppSectionNavigationStack(
                        section: section,
                        homeViewModel: homeViewModel,
                        container: container,
                        navigationResetRequest: navigationResetRequest
                    )
                    .id("\(section.rawValue)-\(navigationResetRequest)")
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
        #endif
    }

    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { AppSection(rawValue: selectedSectionRawValue) ?? .home },
            set: { selectedSectionRawValue = ($0 ?? .home).rawValue }
        )
    }

    private var selectedSection: Binding<AppSection> {
        Binding(
            get: { AppSection(rawValue: selectedSectionRawValue) ?? .home },
            set: { selectedSectionRawValue = $0.rawValue }
        )
    }
}

private struct PresentedPlayer: Identifiable {
    let channelID: String
    let feedID: String?

    init(channelID: String, feedID: String? = nil) {
        self.channelID = channelID
        self.feedID = feedID
    }

    var id: String {
        channelID
    }
}

private extension View {
    @ViewBuilder
    func playerPresentation(
        _ presentedPlayer: Binding<PresentedPlayer?>,
        container: AppContainer
    ) -> some View {
        #if os(macOS)
        sheet(item: presentedPlayer) { presentation in
            PlayerView(
                channelID: presentation.channelID,
                resolveSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched,
                initialFeedID: presentation.feedID,
                closePresentation: { presentedPlayer.wrappedValue = nil }
            )
            .frame(minWidth: 900, minHeight: 600)
        }
        #else
        fullScreenCover(item: presentedPlayer) { presentation in
            PlayerView(
                channelID: presentation.channelID,
                resolveSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched,
                initialFeedID: presentation.feedID,
                closePresentation: { presentedPlayer.wrappedValue = nil }
            )
            .id(presentation.id)
        }
        #endif
    }
}
#endif
