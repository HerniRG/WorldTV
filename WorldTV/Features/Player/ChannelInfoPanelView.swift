import SwiftUI

struct ChannelInfoPanelView: View {
    let info: PlayerChannelInfo
    let selectedFeedID: String?
    var onSelectFeed: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.contentSpacing) {
            HStack(alignment: .top, spacing: 20) {
                logo
                VStack(alignment: .leading, spacing: 8) {
                    Text(info.name)
                        .font(.title.bold())
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

            if !info.feeds.isEmpty {
                Divider()
                feedSelector
            }
        }
        .padding(DesignTokens.pagePadding)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
        )
        .frame(minWidth: 760, minHeight: 480)
    }

    private var feedSelector: some View {
        HStack(spacing: 8) {
            if let selectedFeed = info.feeds.first(where: { $0.id == selectedFeedID }) {
                Label(selectedFeed.displayName, systemImage: "signal")
                    .font(.subheadline.weight(.semibold))
            } else {
                Label("player.feed.auto", systemImage: "signal")
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            if info.feeds.count > 1 {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectFeed?()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("player.feed"))
        .accessibilityHint(Text("Double tap to change feed"))
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
