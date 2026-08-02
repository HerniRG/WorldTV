import SwiftUI

struct CategoryCard: View {
    let item: CategoryCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(item.channelCount.formatted())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [visual.tint, visual.secondaryTint],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .accessibilityLabel(
                    "\(item.channelCount) \(String(localized: "category.channels"))"
                )

                Spacer(minLength: 8)

                Text("category.channels")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(item.category.name)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let description = item.category.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(" ")
                    .font(.subheadline)
                    .hidden()
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text("category.explore")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(visual.tint)
            }
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            minHeight: DesignTokens.categoryCardHeight,
            alignment: .topLeading
        )
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
                .fill(Color.primary.opacity(0.07))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(visual.tint.opacity(0.12))
                        .frame(width: 96, height: 96)
                        .blur(radius: 2)
                        .offset(x: 26, y: -36)
                        .accessibilityHidden(true)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
                        .stroke(visual.tint.opacity(0.22), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.category.name)
        .accessibilityValue(
            "\(item.channelCount) \(String(localized: "category.channels"))"
        )
    }

    private var visual: CategoryVisual {
        CategoryVisual.forCategory(
            id: item.category.id,
            name: item.category.name
        )
    }
}

private struct CategoryVisual {
    let tint: Color
    let secondaryTint: Color

    static func forCategory(id: String, name: String) -> CategoryVisual {
        let value = "\(id) \(name)".lowercased()

        if value.contains("sport") {
            return CategoryVisual(tint: .green, secondaryTint: .teal)
        }
        if value.contains("news") || value.contains("noticia") {
            return CategoryVisual(tint: .blue, secondaryTint: .indigo)
        }
        if value.contains("movie") || value.contains("film") || value.contains("pelicul") {
            return CategoryVisual(tint: .purple, secondaryTint: .pink)
        }
        if value.contains("series") || value.contains("show") {
            return CategoryVisual(tint: .orange, secondaryTint: .red)
        }
        if value.contains("music") || value.contains("musica") {
            return CategoryVisual(tint: .pink, secondaryTint: .purple)
        }
        if value.contains("kid") || value.contains("child") || value.contains("infantil") {
            return CategoryVisual(tint: .yellow, secondaryTint: .orange)
        }
        if value.contains("document") {
            return CategoryVisual(tint: .brown, secondaryTint: .orange)
        }
        if value.contains("culture") || value.contains("cultura") {
            return CategoryVisual(tint: .indigo, secondaryTint: .purple)
        }
        if value.contains("business") || value.contains("econom") {
            return CategoryVisual(tint: .mint, secondaryTint: .green)
        }
        if value.contains("relig") {
            return CategoryVisual(tint: .cyan, secondaryTint: .blue)
        }
        if value.contains("shop") || value.contains("shopping") {
            return CategoryVisual(tint: .red, secondaryTint: .orange)
        }
        if value.contains("weather") || value.contains("tiempo") {
            return CategoryVisual(tint: .cyan, secondaryTint: .blue)
        }
        if value.contains("lifestyle") || value.contains("estilo") {
            return CategoryVisual(tint: .pink, secondaryTint: .red)
        }

        return CategoryVisual(tint: .teal, secondaryTint: .blue)
    }
}
