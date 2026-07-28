import SwiftUI

struct ChannelTile: View {
    let item: ChannelCatalogItem
    let imageLoader: any ImageLoading
    let favoritesStore: FavoritesStore
    var width: CGFloat?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if item.isAvailable {
                NavigationLink(value: AppRoute.player(item.id)) {
                    card
                }
                .buttonStyle(FocusedCardButtonStyle())
            } else {
                card.opacity(0.62)
            }

            Button {
                Task {
                    await favoritesStore.toggle(item.id)
                }
            } label: {
                Image(
                    systemName: favoritesStore.contains(item.id)
                        ? "star.fill"
                        : "star"
                )
                .font(.system(size: DesignTokens.favoriteIconSize, weight: .semibold))
                .foregroundStyle(
                    favoritesStore.contains(item.id) ? Color.yellow : Color.primary
                )
                .frame(
                    width: DesignTokens.favoriteButtonSize,
                    height: DesignTokens.favoriteButtonSize
                )
                .background(Color.black.opacity(0.72), in: Circle())
            }
            .buttonStyle(FocusedIconButtonStyle())
            .padding(DesignTokens.favoriteButtonInset)
            .accessibilityLabel(
                favoritesStore.contains(item.id)
                    ? Text("favorites.remove")
                    : Text("favorites.add")
            )
        }
        .frame(width: width)
        .accessibilityElement(children: .contain)
    }

    private var card: some View {
        ChannelCard(item: item, imageLoader: imageLoader)
            .frame(maxWidth: .infinity)
    }
}

private struct FocusedIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(isFocused ? 1.16 : 1)
                .overlay {
                    Circle()
                        .stroke(isFocused ? Color.primary : .clear, lineWidth: 4)
                }
                .opacity(configuration.isPressed ? 0.72 : 1)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.14),
                    value: isFocused
                )
        }
    }
}
