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
    @State private var navigationPaths: [AppSection: [AppRoute]] = [:]

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
    }

    @ViewBuilder
    private var root: some View {
        #if os(macOS)
        NavigationSplitView {
            AppSidebar(selection: sidebarSelection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 240)
        } detail: {
            AppSectionNavigationStack(
                path: pathBinding(for: sidebarSelection.wrappedValue ?? .home),
                section: sidebarSelection.wrappedValue ?? .home,
                homeViewModel: homeViewModel,
                container: container
            )
        }
        #else
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                AppSidebar(selection: sidebarSelection)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 280)
            } detail: {
                AppSectionNavigationStack(
                    path: pathBinding(for: sidebarSelection.wrappedValue ?? .home),
                    section: sidebarSelection.wrappedValue ?? .home,
                    homeViewModel: homeViewModel,
                    container: container
                )
            }
        } else {
            TabView(selection: selectedSection) {
                ForEach(AppSection.allCases) { section in
                    AppSectionNavigationStack(
                        path: pathBinding(for: section),
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

    private func pathBinding(for section: AppSection) -> Binding<[AppRoute]> {
        Binding(
            get: { navigationPaths[section, default: []] },
            set: { navigationPaths[section] = $0 }
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
                closePresentation: { presentedPlayer.wrappedValue = nil },
                restorePresentation: { presentedPlayer.wrappedValue = presentation }
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
                closePresentation: { presentedPlayer.wrappedValue = nil },
                restorePresentation: { presentedPlayer.wrappedValue = presentation }
            )
        }
        #endif
    }
}
#endif
