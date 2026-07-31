import SwiftUI

struct HorizontalCarousel<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let pitch: CGFloat
    let verticalPadding: CGFloat
    let height: CGFloat?
    let accessibilityIdentifier: String
    let content: (Item) -> Content

    @State private var selection: Item.ID?
    @State private var viewport: CGFloat = 0

    init(
        items: [Item],
        spacing: CGFloat = DesignTokens.contentSpacing,
        pitch: CGFloat = DesignTokens.cardWidth + DesignTokens.contentSpacing,
        verticalPadding: CGFloat = 0,
        height: CGFloat? = nil,
        accessibilityIdentifier: String,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.pitch = pitch
        self.verticalPadding = verticalPadding
        self.height = height
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                        .id(item.id)
                }
            }
            .padding(.vertical, verticalPadding)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selection, anchor: .leading)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.width
        } action: { _, newWidth in
            viewport = newWidth
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        #if os(macOS)
        .overlay(alignment: .leading) { arrow(forward: false) }
        .overlay(alignment: .trailing) { arrow(forward: true) }
        #endif
        #if !os(tvOS)
        .contentMargins(
            .horizontal,
            DesignTokens.pagePadding,
            for: .scrollContent
        )
        .padding(.horizontal, -DesignTokens.pagePadding)
        #endif
        #if os(macOS)
        .frame(height: height)
        #endif
        .tvShelfBehavior()
    }

    #if os(macOS)
    private var itemsPerPage: Int {
        guard viewport > 0 else { return 3 }
        return max(1, Int((viewport - DesignTokens.pagePadding) / pitch))
    }

    private func isDisabled(forward: Bool) -> Bool {
        if forward {
            return selection == items.last?.id
        }
        return selection == nil || selection == items.first?.id
    }

    private func arrow(forward: Bool) -> some View {
        Button {
            scroll(forward: forward)
        } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(isDisabled(forward: forward) ? 0.22 : 1)
        .disabled(isDisabled(forward: forward))
        .padding(.horizontal, 10)
    }

    private func scroll(forward: Bool) {
        guard let target = targetID(forward: forward) else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            selection = target
        }
    }

    private func targetID(forward: Bool) -> Item.ID? {
        let currentIndex = items.firstIndex { $0.id == selection }
            ?? (forward ? -1 : items.count)
        if forward {
            return items[min(currentIndex + itemsPerPage, items.count - 1)].id
        }
        return items[max(currentIndex - itemsPerPage, 0)].id
    }
    #endif
}
