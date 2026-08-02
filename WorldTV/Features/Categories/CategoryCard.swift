import SwiftUI

struct CategoryCard: View {
    let item: CategoryCatalogItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.category.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(item.channelCount) \(String(localized: "category.channels"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let description = item.category.description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
        )
    }
}
