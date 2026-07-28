# WorldTV

WorldTV is a SwiftUI application for discovering free, publicly accessible television channels by using the structured JSON datasets published by [iptv-org](https://github.com/iptv-org/iptv).

## Project status

Phase 5 provides a complete discovery and personalization experience:

- iOS and iPadOS
- macOS
- tvOS
- Swift 6 strict concurrency
- Typed networking with `URLSession` and `async/await`
- DTO decoding and catalog mapping
- Filtering for NSFW, blocked, closed, orphaned, and insecure entries
- Home with featured channels, countries, and categories
- Searchable country browser and channel mosaics
- Asynchronous logos with controlled HTTP caching and cancellation
- Precomputed catalog indexes for large datasets
- A 24-hour persistent catalog cache with stale fallback when the network fails
- Native `AVPlayer` playback from channel cards
- Ordered HLS/quality source selection with automatic fallback and timeout
- Referrer and user-agent forwarding when a stream requires them
- Recently watched channels persisted locally and shown on Home
- Favorites persisted locally and available from Home, channel grids, search, and a dedicated section
- Debounced channel search with country, category, quality, availability, and favorite filters
- Settings for autoplay, preferred playback quality, geoblocked visibility, catalog refresh, cache, and history
- English and Spanish localization
- Accessibility labels, Reduce Motion support, and platform-adaptive interaction effects
- tvOS-specific card sizing and an explicit, shadow-free focus treatment
- Bottom tabs on iPhone and a persistent sidebar on iPad
- A resizable macOS sidebar
- Persistent top-level tabs on tvOS
- Shared typed destinations across every platform root
- Unit tests based on local fixtures

Distribution assets, CI, and the final legal documentation remain for the repository release phase.

## Requirements

- Xcode 26.6 or newer
- iOS/iPadOS 26.5, macOS 26.5, or tvOS 26.5 SDK

Open `WorldTV.xcodeproj`, select the `WorldTV` scheme and choose an iPhone, iPad, Mac, or Apple TV destination.

## Data source and limitations

WorldTV currently reads the channels, streams, logos, countries, categories, and blocklist endpoints from iptv-org. Availability is controlled by third parties. WorldTV does not host, retransmit, or guarantee individual streams.

Formal attribution, takedown information, licensing, and the complete legal disclaimer are scheduled for the repository documentation phase and are required before distribution.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the current dependency flow and concurrency decisions.
