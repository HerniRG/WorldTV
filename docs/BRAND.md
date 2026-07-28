# WorldTV visual identity

WorldTV uses a deep navy broadcast palette with a cyan/teal globe-and-screen symbol and a coral play accent. The symbol has no lettering so it remains legible at small App Icon sizes and across Apple platforms.

## Assets

- `WorldTV/Assets.xcassets/AppIcon.appiconset` contains the iOS 1024×1024 marketing icon and every required macOS raster size.
- `WorldTV/Assets.xcassets/AppIcon.brandassets` contains the small and large layered Apple TV icons plus the standard and wide Top Shelf images.
- `docs/brand` contains the high-resolution source artwork retained for future export work.

The Apple TV icon separates the emblem from the background to support native focus parallax. Top Shelf artwork keeps the central subject inside a conservative safe area so standard and wide crops remain coherent.

## Palette

| Role | Approximate color |
| --- | --- |
| Midnight background | `#00132E` |
| Cyan/teal emblem | `#00AFCA` |
| Coral play accent | `#FF5557` |
| Primary foreground | `#FFFFFF` |

## Generation provenance

The raster masters were created for this repository with OpenAI's built-in image generation tool, then cropped, resized, and assembled into Xcode asset catalogs locally. The layered tvOS foreground was generated on a chroma-key background and converted to a transparent PNG before export.

Prompts specified:

- a square, text-free WorldTV App Icon combining an abstract globe, television screen, and play symbol;
- a wide, text-free Top Shelf composition with a central globe/play motif and generous safe crop;
- a transparent tvOS foreground symbol and a separate, quiet navy world-grid background for parallax.

Do not add channel logos, third-party trademarks, people, or broadcast frames to the first-party brand artwork.
