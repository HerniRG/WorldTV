#if os(tvOS)
import SwiftUI

struct TVRootView: View {
    @SceneStorage("tvos.selectedSection") private var selectedSectionRawValue =
        AppSection.home.rawValue

    let homeViewModel: HomeViewModel
    let container: AppContainer

    var body: some View {
        TabView(selection: selection) {
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

    private var selection: Binding<AppSection> {
        Binding(
            get: { AppSection(rawValue: selectedSectionRawValue) ?? .home },
            set: { selectedSectionRawValue = $0.rawValue }
        )
    }
}
#endif
