import SwiftUI

struct ChannelTile: View {
    @Environment(\.playChannel) private var playChannel
    @Environment(\.colorScheme) private var colorScheme

    let item: ChannelCatalogItem
    let favoritesStore: FavoritesStore
    var width: CGFloat?

    var body: some View {
        #if os(tvOS)
        TVOSChannelTile(item: item, favoritesStore: favoritesStore, width: width)
        #else
        standardCard
        #endif
    }

    private var standardCard: some View {
        ZStack(alignment: .topTrailing) {
            if item.isAvailable {
                Button {
                    playChannel(item.id)
                } label: {
                    card
                }
                .worldTVCardButtonStyle()
                .accessibilityIdentifier("channel.\(item.id).available")
            } else {
                card.opacity(0.62)
            }

            favoriteButton
        }
        .frame(width: width)
        .accessibilityElement(children: .contain)
    }

    private var favoriteButton: some View {
        let isFavorite = favoritesStore.contains(item.id)

        return Button {
            Task {
                await favoritesStore.toggle(item.id)
            }
        } label: {
            Image(
                systemName: isFavorite ? "star.fill" : "star"
            )
            .font(.system(size: DesignTokens.favoriteIconSize, weight: .semibold))
            .foregroundStyle(
                isFavorite ? favoriteAccentColor : Color.primary
            )
            .frame(
                width: DesignTokens.favoriteButtonSize,
                height: DesignTokens.favoriteButtonSize
            )
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle()
                    .stroke(
                        Color.primary.opacity(
                            colorScheme == .dark ? 0.18 : 0.10
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.28 : 0.12),
                radius: 4,
                y: 2
            )
        }
        .buttonStyle(FocusedIconButtonStyle())
        .padding(DesignTokens.favoriteButtonInset)
        .accessibilityLabel(
            favoritesStore.contains(item.id)
                ? Text("favorites.remove")
                : Text("favorites.add")
        )
    }

    private var favoriteAccentColor: Color {
        colorScheme == .dark ? .yellow : .orange
    }

    private var card: some View {
        ChannelCard(item: item)
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
