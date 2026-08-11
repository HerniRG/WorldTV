import SwiftUI

struct ChannelInfoPanelView: View {
    let info: PlayerChannelInfo
    let favoritesStore: FavoritesStore?
    let sleepTimerMinutes: Int?
    let onSleepTimerSelected: @MainActor (Int?) -> Void
    @State private var isFavorite = false
    @State private var selectedSleepTimer: Int?
    @State private var isSleepTimerMenuPresented = false

    init(
        info: PlayerChannelInfo,
        favoritesStore: FavoritesStore?,
        sleepTimerMinutes: Int? = nil,
        onSleepTimerSelected: @escaping @MainActor (Int?) -> Void
    ) {
        self.info = info
        self.favoritesStore = favoritesStore
        self.sleepTimerMinutes = sleepTimerMinutes
        self.onSleepTimerSelected = onSleepTimerSelected
        _selectedSleepTimer = State(initialValue: sleepTimerMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.contentSpacing) {
            HStack(alignment: .top, spacing: 20) {
                logo
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Text(info.name)
                            .font(.title.bold())
                        Spacer()
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

            HStack(spacing: 16) {
                if favoritesStore != nil {
                    favoriteButton
                }
                sleepTimerMenu
            }
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
            FavoriteActionLabel(isFavorite: isFavorite)
        }
        .buttonStyle(PlayerActionButtonStyle(horizontalPadding: 0))
        .accessibilityLabel(
            isFavorite ? Text("favorites.remove") : Text("favorites.add")
        )
        .accessibilityIdentifier("player.favorite")
    }

    private var sleepTimerMenu: some View {
        Button {
            isSleepTimerMenuPresented = true
        } label: {
            SleepTimerActionLabel(selectedMinutes: selectedSleepTimer)
        }
        .buttonStyle(PlayerActionButtonStyle())
        .confirmationDialog(
            "player.sleepTimer",
            isPresented: $isSleepTimerMenuPresented,
            titleVisibility: .visible
        ) {
            Button("player.sleepTimer.off") { selectSleepTimer(nil) }
            Button("player.sleepTimer.15") { selectSleepTimer(15) }
            Button("player.sleepTimer.30") { selectSleepTimer(30) }
            Button("player.sleepTimer.60") { selectSleepTimer(60) }
        }
        .accessibilityIdentifier("player.sleepTimer")
        .accessibilityValue(Text(sleepTimerValue))
    }

    private func selectSleepTimer(_ minutes: Int?) {
        selectedSleepTimer = minutes
        onSleepTimerSelected(minutes)
    }

    private var sleepTimerValue: String {
        guard let selectedSleepTimer else {
            return String(localized: "player.sleepTimer.off")
        }
        return sleepTimerOptionTitle(selectedSleepTimer)
    }

    private func sleepTimerOptionTitle(_ minutes: Int) -> String {
        switch minutes {
        case 15: return String(localized: "player.sleepTimer.15")
        case 30: return String(localized: "player.sleepTimer.30")
        default: return String(localized: "player.sleepTimer.60")
        }
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

private struct FavoriteActionLabel: View {
    let isFavorite: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Image(systemName: isFavorite ? "star.fill" : "star")
            .font(.system(size: DesignTokens.favoriteIconSize, weight: .semibold))
            .foregroundStyle(isFocused ? Color.white : (isFavorite ? Color.yellow : Color.primary))
            .frame(
                width: DesignTokens.favoriteButtonSize,
                height: DesignTokens.favoriteButtonSize
            )
            .accessibilityHidden(true)
    }
}

private struct SleepTimerActionLabel: View {
    let selectedMinutes: Int?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz")
            Text("player.sleepTimer")
                .font(.headline)
            if let selectedMinutes {
                Text("· \(sleepTimerOptionTitle(selectedMinutes))")
                    .font(.subheadline.monospacedDigit())
            }
        }
        .frame(minHeight: DesignTokens.favoriteButtonSize)
    }

    private func sleepTimerOptionTitle(_ minutes: Int) -> String {
        switch minutes {
        case 15: return String(localized: "player.sleepTimer.15")
        case 30: return String(localized: "player.sleepTimer.30")
        default: return String(localized: "player.sleepTimer.60")
        }
    }
}

struct PlayerActionButtonStyle: ButtonStyle {
    let horizontalPadding: CGFloat

    init(horizontalPadding: CGFloat = 18) {
        self.horizontalPadding = horizontalPadding
    }

    func makeBody(configuration: Configuration) -> some View {
        FocusedBody(
            configuration: configuration,
            horizontalPadding: horizontalPadding
        )
    }

    private struct FocusedBody: View {
        let configuration: Configuration
        let horizontalPadding: CGFloat
        @Environment(\.isFocused) private var isFocused
        var body: some View {
            configuration.label
                .foregroundStyle(isFocused ? Color.white : Color.primary)
                .padding(.horizontal, horizontalPadding)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isFocused ? Color.accentColor : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isFocused ? Color.white.opacity(0.9) : Color.clear, lineWidth: 3)
                }
                .opacity(configuration.isPressed ? 0.75 : 1)
        }
    }
}
