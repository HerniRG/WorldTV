#if os(tvOS)
import SwiftUI
import UIKit

struct TVRootView: View {
    @SceneStorage("tvos.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    @State private var navigation = TVNavigationCoordinator()
    @State private var tabBarHasFocus = true
    @State private var presentedChannel: TVDeepLinkChannel?

    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
        @Bindable var navigation = navigation

        NavigationStack(path: $navigation.path) {
            TabView(selection: $navigation.selectedSection) {
                ForEach(AppSection.allCases) { section in
                    AppSectionContent(
                        section: section,
                        homeViewModel: homeViewModel,
                        container: container,
                        tvSearchRequest: section == .search
                            ? navigation.searchRequest
                            : nil,
                        settingsFocusTarget: section == .settings
                            ? navigation.settingsFocusTarget
                            : nil,
                        countryFocusReturn: navigation.countryFocusReturn,
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
            .modifier(AppRouteDestinationModifier(container: container))
        }
        .environment(
            \.playerServices,
            PlayerServices(
                resolveSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched
            )
        )
        .onChange(of: navigation.path) { oldPath, newPath in
            navigation.didChangePath(from: oldPath, to: newPath)
        }
        .onChange(of: navigation.selectedSection) { _, newSection in
            selectedSectionRawValue = newSection.rawValue
            navigation.didSelectSection(newSection)
        }
        .onAppear {
            navigation.restoreSection(rawValue: selectedSectionRawValue)
        }
        .task {
            // HomeView may not be created when tvOS restores the last selected tab.
            // Refresh the shared payload at app startup so Top Shelf is never
            // dependent on the Home tab being visited first.
            await container.topShelfPayloadWriter.write()
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
        guard navigation.selectedSection != .home, tabBarHasFocus else {
            return nil
        }
        return {
            navigation.open(.section(.home))
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
        navigation.open(destination)
    }
}

private struct TVDeepLinkChannel: Identifiable {
    let id = UUID()
    let channelID: String
    let feedID: String?
}
#endif
