import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Sectioned Top Shelf rows render each item as a tile that the system
// fills with the item's image (aspect-fill). A raw channel logo would be
// scaled up to cover the tile and get cropped, so the payload writer
// pre-renders the logo centered on a 16:9 canvas with generous margins and
// references that artwork instead of the original.
enum TopShelfArtworkRenderer {
    // hdtv (16:9) tile for a sectioned content row, @2x.
    static let tileSize = CGSize(width: 888, height: 500)

    static func renderTile(logoData: Data) -> Data? {
        guard
            let source = CGImageSourceCreateWithData(logoData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        let width = Int(tileSize.width)
        let height = Int(tileSize.height)
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        let horizontalMargin = CGFloat(width) * 0.08
        let verticalMargin = CGFloat(height) * 0.14
        let maxWidth = CGFloat(width) - horizontalMargin * 2
        let maxHeight = CGFloat(height) - verticalMargin * 2
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        guard imageWidth > 0, imageHeight > 0 else {
            return nil
        }
        let scale = min(maxWidth / imageWidth, maxHeight / imageHeight)
        let drawSize = CGSize(
            width: imageWidth * scale,
            height: imageHeight * scale
        )
        let drawRect = CGRect(
            x: (CGFloat(width) - drawSize.width) / 2,
            y: (CGFloat(height) - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        context.interpolationQuality = .high
        context.draw(image, in: drawRect)

        guard let output = context.makeImage() else {
            return nil
        }
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }
        CGImageDestinationAddImage(destination, output, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
}
