import SwiftUI

struct BroadcasterCard: View {
    let item: BroadcasterCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(item.logos.prefix(4)) { logo in
                    AsyncImage(url: logo.url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "tv")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 56, height: 40)
                    .background(
                        Color.primary.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .accessibilityHidden(true)
                }
            }
            .frame(height: 56, alignment: .leading)

            Text(item.name)
                .font(.headline)
                .lineLimit(1)
            Text("\(item.channelCount) \(String(localized: "broadcaster.channels"))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: DesignTokens.broadcasterCardWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            Color.primary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
        )
    }
}
