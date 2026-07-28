import SwiftUI

struct CountryCard: View {
    let item: CountryCatalogItem

    private var localizedName: String {
        Locale.current.localizedString(forRegionCode: item.country.code) ?? item.country.name
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(item.country.flag?.isEmpty == false ? item.country.flag ?? "" : "🌐")
                .font(.largeTitle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(item.channelCount) \(String(localized: "country.channels"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
