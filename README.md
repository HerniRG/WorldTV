# WorldTV

WorldTV is a SwiftUI application for discovering free, publicly accessible television channels by using the structured JSON datasets published by [iptv-org](https://github.com/iptv-org/iptv).

## Project status

Phase 1 provides a compiling multiplatform foundation:

- iOS and iPadOS
- macOS
- tvOS
- Swift 6 strict concurrency
- Typed networking with `URLSession` and `async/await`
- DTO decoding and catalog mapping
- Filtering for NSFW, blocked, closed, orphaned, and insecure entries
- A temporary launch screen showing catalog totals
- Unit tests based on local fixtures

Catalog browsing, persistent caching, playback, favorites, search, and final platform-specific navigation belong to later phases.

## Requirements

- Xcode 26.6 or newer
- iOS/iPadOS 26.5, macOS 26.5, or tvOS 26.5 SDK

Open `WorldTV.xcodeproj`, select the `WorldTV` scheme and choose an iPhone, iPad, Mac, or Apple TV destination.

## Data source and limitations

WorldTV currently reads the channels, streams, logos, countries, categories, and blocklist endpoints from iptv-org. Availability is controlled by third parties. WorldTV does not host, retransmit, or guarantee individual streams.

Formal attribution, takedown information, licensing, and the complete legal disclaimer are scheduled for the repository documentation phase and are required before distribution.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the current dependency flow and concurrency decisions.
