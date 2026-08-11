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
        .buttonStyle(PlayerActionButtonStyle(horizontalPadding: 0, isCircular: true))
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
        .accessibilityLabel(Text("player.sleepTimer"))
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
                width: DesignTokens.playerActionButtonSize,
                height: DesignTokens.playerActionButtonSize
            )
            .accessibilityHidden(true)
    }
}

private struct SleepTimerActionLabel: View {
    let selectedMinutes: Int?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz")
            if let selectedMinutes {
                Text("· \(sleepTimerOptionTitle(selectedMinutes))")
                    .font(.subheadline.monospacedDigit())
            } else {
                Text("· \(String(localized: "player.sleepTimer.off"))")
                    .font(.subheadline)
            }
        }
        .font(.headline)
        .frame(minHeight: DesignTokens.playerActionButtonSize)
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
    let isCircular: Bool

    init(horizontalPadding: CGFloat = 24, isCircular: Bool = false) {
        self.horizontalPadding = horizontalPadding
        self.isCircular = isCircular
    }

    func makeBody(configuration: Configuration) -> some View {
        FocusedBody(
            configuration: configuration,
            horizontalPadding: horizontalPadding,
            isCircular: isCircular
        )
    }

    private struct FocusedBody: View {
        let configuration: Configuration
        let horizontalPadding: CGFloat
        let isCircular: Bool
        @Environment(\.isFocused) private var isFocused
        var body: some View {
            configuration.label
                .foregroundStyle(isFocused ? Color.white : Color.primary)
                .padding(.horizontal, horizontalPadding)
                .frame(minHeight: isCircular ? DesignTokens.playerActionButtonSize : nil)
                .background {
                    if isCircular {
                        Circle()
                            .fill(isFocused ? Color.accentColor : Color.primary.opacity(0.16))
                    } else {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(isFocused ? Color.accentColor : Color.primary.opacity(0.16))
                    }
                }
                .overlay {
                    if isCircular {
                        Circle()
                            .stroke(isFocused ? Color.white : Color.white.opacity(0.22), lineWidth: isFocused ? 4 : 1)
                    } else {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isFocused ? Color.white : Color.white.opacity(0.22), lineWidth: isFocused ? 4 : 1)
                    }
                }
                .scaleEffect(isFocused ? 1.05 : 1)
                .opacity(configuration.isPressed ? 0.75 : 1)
                .zIndex(isFocused ? 1 : 0)
                .animation(.easeOut(duration: 0.14), value: isFocused)
        }
    }
}
