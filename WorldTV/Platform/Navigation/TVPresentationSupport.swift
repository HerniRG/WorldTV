import SwiftUI

private struct PlayChannelActionKey: EnvironmentKey {
    static let defaultValue: @MainActor (String) -> Void = { _ in }
}

private struct OpenTVTopLevelDestinationKey: EnvironmentKey {
    static let defaultValue: @MainActor (TVTopLevelDestination) -> Void = { _ in }
}

enum TVTopLevelDestination {
    case section(AppSection)
    case searchCategory(String)
    case searchCountry(String)
}

struct TVSearchRequest {
    let id = UUID()
    let categoryID: String?
    let countryCode: String?

    init(categoryID: String? = nil, countryCode: String? = nil) {
        self.categoryID = categoryID
        self.countryCode = countryCode
    }
}

extension EnvironmentValues {
    var playChannel: @MainActor (String) -> Void {
        get { self[PlayChannelActionKey.self] }
        set { self[PlayChannelActionKey.self] = newValue }
    }

    var openTVTopLevelDestination: @MainActor (TVTopLevelDestination) -> Void {
        get { self[OpenTVTopLevelDestinationKey.self] }
        set { self[OpenTVTopLevelDestinationKey.self] = newValue }
    }
}

struct TVScreenHeader: View {
    private let title: Text
    private let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = Text(title)
        self.systemImage = systemImage
    }

    init(verbatim title: String, systemImage: String) {
        self.title = Text(verbatim: title)
        self.systemImage = systemImage
    }

    var body: some View {
        #if os(tvOS)
        Label {
            title
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 52, weight: .bold))
        .foregroundStyle(.primary)
        .accessibilityAddTraits(.isHeader)
        #else
        EmptyView()
        #endif
    }
}

private struct PlatformNavigationTitleModifier: ViewModifier {
    let title: Text

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
        #else
        content.navigationTitle(title)
        #endif
    }
}

extension View {
    func platformNavigationTitle(_ title: LocalizedStringKey) -> some View {
        modifier(PlatformNavigationTitleModifier(title: Text(title)))
    }

    func platformNavigationTitle(verbatim title: String) -> some View {
        modifier(
            PlatformNavigationTitleModifier(title: Text(verbatim: title))
        )
    }

    @ViewBuilder
    func worldTVCardButtonStyle() -> some View {
        #if os(tvOS)
        buttonStyle(.card)
        #else
        buttonStyle(FocusedCardButtonStyle())
        #endif
    }

    @ViewBuilder
    func tvShelfBehavior() -> some View {
        #if os(tvOS)
        scrollClipDisabled()
            .focusSection()
        #else
        self
        #endif
    }
}
