import SwiftUI

#if os(tvOS)
import CoreImage.CIFilterBuiltins
#endif

struct AboutView: View {
    var body: some View {
        Form {
            #if os(tvOS)
            TVScreenHeader("settings.about", systemImage: "info.circle")
                .listRowBackground(Color.clear)
            #endif

            Section("about.worldtv") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("about.description")
                    Text("about.availability")
                }
                .invisibleTVOSFocus()
            }

            Section("about.attribution") {
                Text("sources.aboutDisclaimer")
                    .invisibleTVOSFocus()
                #if os(tvOS)
                AboutQRCodeGrid(destinations: [.sourceCode, .support])
                #else
                if let destination = AboutDestination.sourceCode.url {
                    Link("about.sourceCode", destination: destination)
                }
                if let destination = AboutDestination.support.url {
                    Link("about.support", destination: destination)
                }
                #endif
            }

            Section("about.legal") {
                Text("about.legalNotice")
                    .invisibleTVOSFocus()
                #if os(tvOS)
                AboutQRCodeGrid(destinations: [.privacy, .disclaimer])
                #else
                if let destination = AboutDestination.privacy.url {
                    Link("about.privacy", destination: destination)
                }
                if let destination = AboutDestination.disclaimer.url {
                    Link("about.disclaimer", destination: destination)
                }
                #endif
            }
        }
        .platformNavigationTitle("settings.about")
    }
}

#if os(tvOS)
private struct AboutQRCodeGrid: View {
    let destinations: [AboutDestination]

    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(destinations, id: \.self) { destination in
                AboutQRCodeCard(destination: destination)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct AboutQRCodeCard: View {
    let destination: AboutDestination

    var body: some View {
        VStack(spacing: 12) {
            if let image = destination.qrCodeImage {
                Image(decorative: image, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text(destination.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("about.qrInstruction")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .focusable()
        .focusEffectDisabled()
    }
}

private extension AboutDestination {
    var title: LocalizedStringKey {
        switch self {
        case .sourceCode: return "about.sourceCode"
        case .support: return "about.support"
        case .privacy: return "about.privacy"
        case .disclaimer: return "about.disclaimer"
        }
    }

    var qrCodeImage: CGImage? {
        guard let data = rawValue.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        return CIContext().createCGImage(outputImage, from: outputImage.extent)
    }
}
#endif

private extension View {
    @ViewBuilder
    func invisibleTVOSFocus() -> some View {
        #if os(tvOS)
        self
            .focusable()
            .focusEffectDisabled()
        #else
        self
        #endif
    }
}

enum AboutDestination: String, CaseIterable {
    case sourceCode = "https://github.com/HerniRG/WorldTV"
    case support = "https://github.com/HerniRG/WorldTV/blob/main/SUPPORT.md"
    case privacy = "https://github.com/HerniRG/WorldTV/blob/main/PRIVACY.md"
    case disclaimer = "https://github.com/HerniRG/WorldTV/blob/main/DISCLAIMER.md"

    var url: URL? {
        URL(string: rawValue)
    }
}
