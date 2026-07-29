import SwiftUI

struct ChannelTile: View {
    @Environment(\.playChannel) private var playChannel

    let item: ChannelCatalogItem
    let imageLoader: any ImageLoading
    let favoritesStore: FavoritesStore
    var width: CGFloat?

    var body: some View {
        #if os(tvOS)
        tvOSCard
        #else
        standardCard
        #endif
    }

    #if os(tvOS)
    private var tvOSCard: some View {
        Button {
            playChannel(item.id)
        } label: {
            card
                .overlay(alignment: .topTrailing) {
                    if favoritesStore.contains(item.id) {
                        favoriteStatus
                    }
                }
        }
        .worldTVCardButtonStyle()
        .contextMenu {
            Button {
                Task {
                    await favoritesStore.toggle(item.id)
                }
            } label: {
                Label(
                    favoritesStore.contains(item.id)
                        ? "favorites.remove"
                        : "favorites.add",
                    systemImage: favoritesStore.contains(item.id)
                        ? "star.slash"
                        : "star"
                )
            }
        }
        .disabled(!item.isAvailable)
        .opacity(item.isAvailable ? 1 : 0.62)
        .frame(width: width)
        .accessibilityIdentifier("channel.\(item.id)")
        .accessibilityHint(Text("channel.play.hint"))
    }

    private var favoriteStatus: some View {
        Image(systemName: "star.fill")
            .font(.system(size: DesignTokens.favoriteIconSize, weight: .semibold))
            .foregroundStyle(.yellow)
            .frame(
                width: DesignTokens.favoriteButtonSize,
                height: DesignTokens.favoriteButtonSize
            )
            .background(.black.opacity(0.78), in: Circle())
            .padding(DesignTokens.favoriteButtonInset)
            .accessibilityHidden(true)
    }
    #endif

    private var standardCard: some View {
        ZStack(alignment: .topTrailing) {
            if item.isAvailable {
                NavigationLink(value: AppRoute.player(item.id)) {
                    card
                }
                .worldTVCardButtonStyle()
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
