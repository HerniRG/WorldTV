import SwiftUI

struct AppSidebar: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(AppSection.allCases, selection: $selection) { section in
            Label(
                LocalizedStringKey(section.localizationKey),
                systemImage: section.systemImage
            )
                .tag(section)
        }
        .navigationTitle("app.name")
    }
}
