import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ChannelLogoView: View {
    let logo: ChannelLogo?
    let channelName: String
    let imageLoader: any ImageLoading

    @State private var image: Image?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignTokens.logoHeight)
        .accessibilityLabel(channelName)
        .task(id: logo?.url) {
            await loadImage()
        }
    }

    private var fallback: some View {
        Image(systemName: "tv")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    @MainActor
    private func loadImage() async {
        image = nil
        guard let logo else {
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await imageLoader.data(from: logo.url)
            guard !Task.isCancelled else {
                return
            }
#if os(macOS)
            if let platformImage = NSImage(data: data) {
                image = Image(nsImage: platformImage)
            }
#else
            if let platformImage = UIImage(data: data) {
                image = Image(uiImage: platformImage)
            }
#endif
        } catch {
            image = nil
        }
    }
}
