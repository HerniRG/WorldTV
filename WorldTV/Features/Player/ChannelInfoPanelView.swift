import SwiftUI

struct ChannelInfoPanelView: View {
    let info: PlayerChannelInfo
    let favoritesStore: FavoritesStore?
    let onSleepTimerSelected: @MainActor (Int?) -> Void
    @State private var isFavorite = false
    @State private var selectedSleepTimer: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.contentSpacing) {
            HStack(alignment: .top, spacing: 20) {
                logo
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Text(info.name)
                            .font(.title.bold())
                        Spacer()
                        if favoritesStore != nil {
                            favoriteButton
                        }
                    }
                    if !info.broadcasterName.isEmpty {
                        Label(info.broadcasterName, systemImage: "building.2")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !info.countryName.isEmpty {
                Label(info.countryName, systemImage: "globe")
                    .font(.subheadline)
            }
            if !info.categoryNames.isEmpty {
                Label(
                    info.categoryNames.joined(separator: " · "),
                    systemImage: "square.grid.2x2"
                )
                .font(.subheadline)
            }
            if let network = info.network, !network.isEmpty {
                Label(network, systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let launched = info.launched, !launched.isEmpty {
                Label("channel.emitsSince \(launched)", systemImage: "calendar.badge.plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            sleepTimerMenu
        }
        .padding(DesignTokens.pagePadding)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if os(tvOS)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        #else
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
        )
        #endif
        .frame(minWidth: 760, minHeight: 480)
        .task {
            if let favoritesStore {
                await favoritesStore.loadIfNeeded()
                isFavorite = favoritesStore.contains(info.channelID)
            }
        }
    }

    private var favoriteButton: some View {
        Button {
            Task {
                guard let favoritesStore else { return }
                await favoritesStore.toggle(info.channelID)
                isFavorite = favoritesStore.contains(info.channelID)
            }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: DesignTokens.favoriteIconSize, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.yellow : Color.primary)
                .frame(
                    width: DesignTokens.favoriteButtonSize,
                    height: DesignTokens.favoriteButtonSize
                )
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(InfoPanelFavoriteButtonStyle())
        .accessibilityLabel(
            isFavorite ? Text("favorites.remove") : Text("favorites.add")
        )
        .accessibilityIdentifier("player.favorite")
    }

    private var sleepTimerMenu: some View {
        Menu {
            Button("player.sleepTimer.off") {
                selectedSleepTimer = nil
                onSleepTimerSelected(nil)
            }
            Button("15 min") {
                selectedSleepTimer = 15
                onSleepTimerSelected(15)
            }
            Button("30 min") {
                selectedSleepTimer = 30
                onSleepTimerSelected(30)
            }
            Button("60 min") {
                selectedSleepTimer = 60
                onSleepTimerSelected(60)
            }
        } label: {
            Label("player.sleepTimer", systemImage: "moon.zzz")
                .font(.headline)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("player.sleepTimer")
        .accessibilityValue(Text(sleepTimerValue))
    }

    private var sleepTimerValue: String {
        guard let selectedSleepTimer else {
            return String(localized: "player.sleepTimer.off")
        }
        return "\(selectedSleepTimer) min"
    }

    private var logo: some View {
        Group {
            if let url = info.logoURL {
                AsyncImage(url: url, transaction: Transaction(animation: .default)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        fallbackLogo
                    @unknown default:
                        fallbackLogo
                    }
                }
                .accessibilityLabel(info.name)
            } else {
                fallbackLogo
            }
        }
        .frame(width: 200, height: 110)
        .accessibilityHidden(true)
    }

    private var fallbackLogo: some View {
        Image(systemName: "tv")
            .font(.system(size: 52))
            .foregroundStyle(.secondary)
            .frame(width: 200, height: 110)
    }
}

private struct InfoPanelFavoriteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FocusedBody(configuration: configuration)
    }

    private struct FocusedBody: View {
        let configuration: Configuration
        @Environment(\.isFocused) private var isFocused
        var body: some View {
            configuration.label
                .overlay {
                    Circle()
                        .stroke(
                            isFocused ? Color.primary : Color.clear,
                            lineWidth: 4
                        )
                }
                .scaleEffect(isFocused ? 1.16 : 1)
                .opacity(configuration.isPressed ? 0.72 : 1)
        }
    }
}
