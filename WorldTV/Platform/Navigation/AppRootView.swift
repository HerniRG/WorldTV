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
                closePresentation: { presentedPlayer.wrappedValue = nil }
            )
            .frame(minWidth: 900, minHeight: 600)
        }
        #else
        background(
            IOSNativePlayerPresenter(
                presentation: presentedPlayer,
                container: container
            )
        )
        #endif
    }
}

#if os(iOS)
private struct IOSNativePlayerPresenter: UIViewControllerRepresentable {
    @Binding var presentation: PresentedPlayer?
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
        private var pendingPresentation: PresentedPlayer?
        private var pendingContainer: AppContainer?
        private var onDismiss: (@MainActor () -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            view.backgroundColor = .clear
            presentPendingPlayerIfPossible()
        }

        func update(
            presentation: PresentedPlayer?,
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
            if let player {
                player.dismiss(animated: false) { [weak self] in
                    self?.onDismiss?()
                }
            }
        }
    }
}
#endif
#endif
