import SwiftUI

struct CatalogRefreshToolbar: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
#if os(tvOS)
        content
#else
        content.toolbar {
            ToolbarItem {
                Button(action: action) {
                    Label("catalog.refresh", systemImage: "arrow.clockwise")
                }
            }
        }
#endif
    }
}
