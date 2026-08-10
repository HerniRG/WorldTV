#if os(tvOS)
import SwiftUI
import UIKit

struct TVRootView: View {
    @SceneStorage("tvos.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    @State private var navigation = TVNavigationCoordinator()
    @State private var tabBarHasFocus = true
    @State private var presentedChannel: TVPlayerPresentation?

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
        .environment(\.playChannel) { channelID in
            presentedChannel = TVPlayerPresentation(channelID: channelID)
        }
        .environment(\.playChannelWithInitialFeed) { channelID, feedID in
            presentedChannel = TVPlayerPresentation(
                channelID: channelID,
                feedID: feedID
            )
        }
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
        .background(
            TVNativePlayerPresenter(
                presentation: $presentedChannel,
                container: container
            )
        )
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "worldtv", url.host == "play" else {
            return
        }
        let components = url.pathComponents
        guard components.count >= 2, !components[1].isEmpty else {
            return
        }
        presentedChannel = TVPlayerPresentation(
            channelID: components[1],
            feedID: nil
        )
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

private struct TVPlayerPresentation: Identifiable {
    let id = UUID()
    let channelID: String
    let feedID: String?

    init(channelID: String, feedID: String? = nil) {
        self.channelID = channelID
        self.feedID = feedID
    }
}

private struct TVNativePlayerPresenter: UIViewControllerRepresentable {
    @Binding var presentation: TVPlayerPresentation?
    let container: AppContainer

    func makeUIViewController(context: Context) -> PresenterViewController {
        PresenterViewController()
    }

    func updateUIViewController(
        _ controller: PresenterViewController,
        context: Context
    ) {
        controller.update(
            presentation: presentation,
            container: container,
            onDismiss: { presentation = nil }
        )
    }

    @MainActor
    final class PresenterViewController: UIViewController {
        private var presentedPlayer: UIViewController?
        private var presentedID: UUID?
        private var pendingPresentation: TVPlayerPresentation?
        private var pendingContainer: AppContainer?
        private var onDismiss: (@MainActor () -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            view.backgroundColor = .clear
            presentPendingPlayerIfPossible()
        }

        func update(
            presentation: TVPlayerPresentation?,
            container: AppContainer,
            onDismiss: @escaping @MainActor () -> Void
        ) {
            pendingPresentation = presentation
            pendingContainer = container
            self.onDismiss = onDismiss

            if presentation == nil {
                dismissPresentedPlayer()
                return
            }

            presentPendingPlayerIfPossible()
        }

        private func presentPendingPlayerIfPossible() {
            guard
                viewIfLoaded?.window != nil,
                presentedPlayer == nil,
                let presentation = pendingPresentation,
                let container = pendingContainer
            else {
                return
            }

            presentedID = presentation.id
            let player = PlayerView(
                channelID: presentation.channelID,
                resolveSources: container.resolvePlaybackSources,
                recordRecentlyWatched: container.recordRecentlyWatched,
                initialFeedID: presentation.feedID,
                closePresentation: { [weak self] in
                    self?.dismissPresentedPlayer()
                },
                dismissForPictureInPicture: { [weak self] in
                    self?.dismissPresentedPlayerForPictureInPicture()
                },
                restorePresentation: { [weak self] in
                    self?.restorePresentedPlayer()
                }
            )
            let hosting = UIHostingController(rootView: player)
            hosting.modalPresentationStyle = .fullScreen
            presentedPlayer = hosting
            present(hosting, animated: false)
        }

        private func dismissPresentedPlayerForPictureInPicture() {
            guard let player = presentedPlayer else {
                return
            }

            player.dismiss(animated: false)
        }

        private func restorePresentedPlayer() {
            guard
                let player = presentedPlayer,
                player.presentingViewController == nil,
                viewIfLoaded?.window != nil
            else {
                return
            }

            present(player, animated: false)
        }

        private func dismissPresentedPlayer() {
            pendingPresentation = nil
            let player = presentedPlayer
            presentedPlayer = nil
            presentedID = nil
            if let player {
                player.dismiss(animated: false) { [weak self] in
                    self?.onDismiss?()
                }
            }
        }
    }
}
#endif
