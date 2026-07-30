#if os(tvOS)
import SwiftUI
import UIKit

struct TVRootView: View {
    @SceneStorage("tvos.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    @State private var selectedSection = AppSection.home
    @State private var searchRequest: TVSearchRequest?
    @State private var tabBarHasFocus = true

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
        .onChange(of: selectedSection) {
            selectedSectionRawValue = selectedSection.rawValue
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
        case .searchCategory(let categoryID):
            searchRequest = TVSearchRequest(categoryID: categoryID)
            selectedSection = .search
        case .searchCountry(let countryCode):
            searchRequest = TVSearchRequest(countryCode: countryCode)
            selectedSection = .search
        }
    }
}
#endif
