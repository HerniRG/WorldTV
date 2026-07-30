import SwiftUI

struct ChannelTile: View {
    @Environment(\.playChannel) private var playChannel
    #if os(tvOS)
    @Environment(\.playerServices) private var playerServices
    @State private var presentsPlayer = false
    @FocusState private var isFocused: Bool
    #endif

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
                        playerServices.recordRecentlyWatched
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
    #endif

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
