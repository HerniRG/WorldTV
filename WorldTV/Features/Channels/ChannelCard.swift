import SwiftUI

struct ChannelCard: View {
    let item: ChannelCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChannelLogoView(
                logo: item.logo,
                channelName: item.channel.name
            )

            Text(item.channel.name)
                .font(.headline)
                .lineLimit(2, reservesSpace: true)

            Text(
                Locale.current.localizedString(
                    forRegionCode: item.channel.countryCode
                ) ?? item.countryName
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            HStack(spacing: 10) {
                if let quality = item.quality {
                    Text(quality)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }

                if item.isGeoBlocked {
                    Image(systemName: "location.slash")
                        .accessibilityLabel(Text("channel.geoblocked"))
                }

                Spacer(minLength: 0)

                Image(systemName: item.isAvailable ? "play.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(item.isAvailable ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(
                        item.isAvailable
                            ? Text("channel.available")
                            : Text("channel.unavailable")
                    )
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
        .modifier(CardInteractionEffect())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.channel.name)
        .accessibilityValue(
            item.isAvailable
                ? Text("channel.available")
                : Text("channel.unavailable")
        )
    }
}
