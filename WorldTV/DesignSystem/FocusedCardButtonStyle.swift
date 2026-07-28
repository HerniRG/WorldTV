import SwiftUI

struct FocusedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FocusedCard(configuration: configuration)
    }

    private struct FocusedCard: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(
                    configuration.isPressed ? 0.98 : (isFocused ? 1.06 : 1)
                )
                .brightness(isFocused ? 0.08 : 0)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
                        .stroke(
                            isFocused ? Color.accentColor : Color.clear,
                            lineWidth: isFocused ? 6 : 0
                        )
                }
                .opacity(configuration.isPressed ? 0.82 : 1)
                .zIndex(isFocused ? 1 : 0)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.16),
                    value: isFocused
                )
        }
    }
}
