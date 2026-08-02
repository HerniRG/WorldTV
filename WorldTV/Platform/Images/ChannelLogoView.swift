import SwiftUI

struct ChannelLogoView: View {
    let logos: [ChannelLogo]
    let channelName: String
    @State private var failedLogoIDs: Set<URL> = []

    init(logo: ChannelLogo?, channelName: String) {
        self.init(logos: logo.map { [$0] } ?? [], channelName: channelName)
    }

    init(logos: [ChannelLogo], channelName: String) {
        self.logos = logos
        self.channelName = channelName
    }

    var body: some View {
        Group {
            if let logo = logos.first(where: { !failedLogoIDs.contains($0.id) }) {
                AsyncImage(url: logo.url, transaction: Transaction(animation: .default)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        fallbackToNextLogo(after: logo)
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignTokens.logoHeight)
        .accessibilityLabel(channelName)
        .onChange(of: logos.map(\.id)) { _, _ in
            failedLogoIDs = []
        }
    }

    private func fallbackToNextLogo(after logo: ChannelLogo) -> some View {
        Color.clear
            .onAppear {
                failedLogoIDs.insert(logo.id)
            }
            .overlay { fallbackLogoIfNeeded }
    }

    @ViewBuilder
    private var fallbackLogoIfNeeded: some View {
        if logos.dropFirst().allSatisfy({ failedLogoIDs.contains($0.id) }) {
            fallback
        } else {
            ProgressView()
        }
    }

    private var fallback: some View {
        Image(systemName: "tv")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}
