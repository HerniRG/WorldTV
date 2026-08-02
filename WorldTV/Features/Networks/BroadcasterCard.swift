import SwiftUI

struct BroadcasterCard: View {
    let item: BroadcasterCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if item.logos.isEmpty {
                    BroadcasterLogoPlaceholder(name: item.name)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(item.logos.prefix(4)) { logo in
                        AsyncImage(url: logo.url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(8)
                        } placeholder: {
                            BroadcasterLogoPlaceholder(name: item.name)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            Color.primary.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 58, alignment: .leading)

            Text(item.name)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(item.channelCount) \(String(localized: "broadcaster.channels"))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
        }
        .padding()
        .frame(width: DesignTokens.broadcasterCardWidth, alignment: .leading)
        .frame(minHeight: DesignTokens.broadcasterRowHeight - 20, alignment: .top)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
    }
}

private struct BroadcasterLogoPlaceholder: View {
    let name: String

    var body: some View {
        Text(initials)
            .font(.headline.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }
}
