import SwiftUI

struct ChannelLogoView: View {
    let logo: ChannelLogo?
    let channelName: String

    var body: some View {
        Group {
            if let logo {
                AsyncImage(url: logo.url, transaction: Transaction(animation: .default)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        fallback
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
    }

    private var fallback: some View {
        Image(systemName: "tv")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}
