import SwiftUI

struct ChannelCard: View {
    let item: ChannelCatalogItem
    let imageLoader: any ImageLoading

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChannelLogoView(
                logo: item.logo,
                channelName: item.channel.name,
                imageLoader: imageLoader
            )

            Text(item.channel.name)
                .font(.headline)
                .lineLimit(2)

            HStack {
                if let quality = item.quality {
                    Text(quality)
                        .font(.caption.weight(.semibold))
                }
                Spacer()
                Image(systemName: item.isAvailable ? "play.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(item.isAvailable ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(
                        item.isAvailable
                            ? Text("channel.available")
                            : Text("channel.unavailable")
                    )
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
    }
}
