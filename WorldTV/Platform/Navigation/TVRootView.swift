#if os(tvOS)
import SwiftUI
import UIKit

struct TVRootView: View {
    @SceneStorage("tvos.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    @State private var selectedSection = AppSection.home
    @State private var searchRequest: TVSearchRequest?
    @State private var focusSourcesRequest = 0
    @State private var navigationResetRequest = 0
    @State private var tabBarHasFocus = true
    @State private var presentedChannel: TVDeepLinkChannel?

    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
        TabView(selection: $selectedSection) {
            ForEach(AppSection.allCases) { section in
                AppSectionNavigationStack(
                    section: section,
                    homeViewModel: homeViewModel,
                    container: container,
                    tvSearchRequest: section == .search ? searchRequest : nil,
                    tvFocusSourcesRequest: section == .settings ? focusSourcesRequest : 0,
                    tvNavigationResetRequest: navigationResetRequest,
                    tvOpenTopLevelDestination: openTopLevelDestination
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
        .onAppear {
            selectedSection = AppSection(rawValue: selectedSectionRawValue) ?? .home
        }
        .task {
            // HomeView may not be created when tvOS restores the last selected tab.
            // Refresh the shared payload at app startup so Top Shelf is never
            // dependent on the Home tab being visited first.
            await container.topShelfPayloadWriter.write()
        }
        .onChange(of: selectedSection) {
            selectedSectionRawValue = selectedSection.rawValue
            navigationResetRequest += 1
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIFocusSystem.didUpdateNotification
            )
        ) { notification in
            guard
                let context = notification.userInfo?[
                    UIFocusSystem.focusUpdateContextUserInfoKey
                ] as? UIFocusUpdateContext
            else {
                return
            }
            tabBarHasFocus = isTabBarFocus(context.nextFocusedItem)
        }
        .onExitCommand(perform: exitCommand)
        .onReceive(
            NotificationCenter.default.publisher(for: .topShelfDataDidChange)
        ) { _ in
            Task {
                await container.topShelfPayloadWriter.write()
            }
        }
        .onOpenURL(perform: handleURL)
        .fullScreenCover(item: $presentedChannel) { channel in
            PlayerView(
                channelID: channel.channelID,
                resolveSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched,
                initialFeedID: channel.feedID,
                closePresentation: {
                    presentedChannel = nil
                }
            )
            .id(channel.channelID)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "worldtv", url.host == "play" else {
            return
        }
        let components = url.pathComponents
        guard components.count >= 2, !components[1].isEmpty else {
            return
        }
        presentedChannel = TVDeepLinkChannel(channelID: components[1], feedID: nil)
    }

    private var exitCommand: (() -> Void)? {
        guard selectedSection != .home, tabBarHasFocus else {
            return nil
        }
        return {
            selectedSection = .home
        }
    }

    private func isTabBarFocus(_ item: (any UIFocusItem)?) -> Bool {
        var view = item as? UIView
        while let currentView = view {
            if currentView is UITabBar {
                return true
            }
            view = currentView.superview
        }
        return false
    }

    private func openTopLevelDestination(_ destination: TVTopLevelDestination) {
        switch destination {
        case .section(let section):
            selectedSection = section
        case .sources:
            focusSourcesRequest += 1
            selectedSection = .settings
        case .searchCategory(let categoryID):
            searchRequest = TVSearchRequest(categoryID: categoryID)
            selectedSection = .search
        case .searchCountry(let countryCode):
            searchRequest = TVSearchRequest(countryCode: countryCode)
            selectedSection = .search
        }
    }
}

private struct TVDeepLinkChannel: Identifiable {
    let id = UUID()
    let channelID: String
    let feedID: String?
}
#endif
