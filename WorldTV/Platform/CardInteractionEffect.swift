import SwiftUI

struct CardInteractionEffect: ViewModifier {
    #if os(macOS)
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #endif

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .scaleEffect(isHovering ? 1.015 : 1)
            .brightness(isHovering ? 0.035 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.14),
                value: isHovering
            )
            .onHover { isHovering = $0 }
        #else
        content
        #endif
    }
}
