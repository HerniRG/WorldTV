#if os(tvOS)
import SwiftUI

struct TVRootView: View {
    @SceneStorage("tvos.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue
    @State private var selectedSection = AppSection.home
    @State private var searchRequest: TVSearchRequest?

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
    }

    private func openTopLevelDestination(_ destination: TVTopLevelDestination) {
        switch destination {
        case .section(let section):
            selectedSection = section
        case .searchCategory(let categoryID):
            searchRequest = TVSearchRequest(categoryID: categoryID)
            selectedSection = .search
        }
    }
}
#endif
