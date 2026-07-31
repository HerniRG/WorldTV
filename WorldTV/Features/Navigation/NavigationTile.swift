import SwiftUI

struct NavigationTile<Label: View>: View {
    @Environment(\.openTVTopLevelDestination) private var openTVTopLevelDestination

    var route: AppRoute?
    var tvDestination: TVTopLevelDestination?
    var accessibilityID: String?
    var tvAccessibilityID: String?

    @ViewBuilder
    private var label: () -> Label

    init(
        route: AppRoute? = nil,
        tvDestination: TVTopLevelDestination? = nil,
        accessibilityID: String? = nil,
        tvAccessibilityID: String? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.route = route
        self.tvDestination = tvDestination
        self.accessibilityID = accessibilityID
        self.tvAccessibilityID = tvAccessibilityID
        self.label = label
    }

    var body: some View {
        #if os(tvOS)
        Button {
            if let tvDestination {
                openTVTopLevelDestination(tvDestination)
            }
        } label: {
            label()
        }
        .accessibilityIdentifier(tvAccessibilityID ?? accessibilityID ?? "")
        #else
        if let route {
            NavigationLink(value: route) {
                label()
            }
            .accessibilityIdentifier(accessibilityID ?? "")
        } else {
            label()
        }
        #endif
    }
}
