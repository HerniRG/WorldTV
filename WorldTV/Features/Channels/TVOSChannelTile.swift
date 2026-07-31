#if os(tvOS)
import SwiftUI

struct TVOSChannelTile: View {
    @Environment(\.playerServices) private var playerServices
    @State private var presentsPlayer = false
    @FocusState private var isFocused: Bool

    let item: ChannelCatalogItem
    let favoritesStore: FavoritesStore
    var width: CGFloat?

    var body: some View {
        Button {
            if item.isAvailable {
                presentsPlayer = true
            }
        } label: {
            card
                .overlay(alignment: .topTrailing) {
                    if favoritesStore.contains(item.id) {
                        favoriteStatus
                    }
                }
        }
        .focused($isFocused)
        .defaultFocus(
            $isFocused,
            true,
            priority: .userInitiated
        )
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
        .opacity(item.isAvailable ? 1 : 0.62)
        .frame(width: width)
        .accessibilityIdentifier(
            "channel.\(item.id).\(item.isAvailable ? "available" : "unavailable")"
        )
        .accessibilityHint(
            item.isAvailable
                ? Text("channel.play.hint")
                : Text("channel.unavailable")
        )
        .fullScreenCover(
            isPresented: $presentsPlayer,
            onDismiss: restoreFocus
        ) {
            if let playerServices {
                PlayerView(
                    channelID: item.id,
                    resolveSources: playerServices.resolveSources,
                    recordRecentlyWatched:
                        playerServices.recordRecentlyWatched,
                    closePresentation: {
                        presentsPlayer = false
                    }
                )
            }
        }
    }

    private func restoreFocus() {
        Task { @MainActor in
            isFocused = false
            try? await Task.sleep(for: .milliseconds(300))
            isFocused = true
        }
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

    private var card: some View {
        ChannelCard(item: item)
            .frame(maxWidth: .infinity)
    }
}
#endif
