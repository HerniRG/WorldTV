# Changelog

All notable changes to WorldTV will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project intends to use [Semantic Versioning](https://semver.org/spec/v2.0.0.html) after its first tagged release.

## [Unreleased]

### Added

- Native SwiftUI application for iOS, iPadOS, macOS, and tvOS
- Structured iptv-org catalog loading, mapping, exclusions, indexing, and persistent cache
- Home, countries, channel grids, asynchronous logos, search, and filters
- AVPlayer playback with source ordering, fallback, timeouts, headers, and recent history
- Favorites, settings, playback preferences, English and Spanish localization
- Platform-native navigation, accessibility, tvOS focus, and macOS hover behavior
- Swift Testing coverage for catalog, persistence, cache, search, and playback logic
- Repository documentation, MIT license, disclaimer, security policy, and contribution guide
- GitHub Actions builds for iOS Simulator, tvOS Simulator, and macOS
- Offline unit-test workflow and cross-platform UI launch smoke test
- Channel-removal issue template and screenshot capture checklist
- Final WorldTV visual identity with complete iOS and macOS App Icon sizes
- Layered Apple TV App Icon with parallax foreground/background artwork
- Standard and wide Apple TV Top Shelf images
- Real 1920×1080 Apple TV Home screenshot and README preview
- Signed physical Apple TV build validation, installation, and launch
- Scroll-aware tvOS screen headers, native card focus, and view-aligned channel shelves
- Full-screen tvOS playback with native transport controls and Siri Remote back behavior
- tvOS UI regression coverage for scrolling headers, full-screen playback, and focus restoration
- Focusable unavailable tvOS channels and a scroll-aligned Search filter action with a bounded filter panel
- tvOS Home shortcuts now select the Countries, Search, and Favorites tabs while preserving category intent
- tvOS popular countries on Home now open the main Search tab with the selected country applied
- tvOS Menu first restores focus to a secondary tab before returning Home, filter sublists return to their parent with unclipped focus effects, and grids restore the originating item after navigation or playback
- Native AVKit overlay timing and a single player-error action that returns to the originating screen
- Full-screen iPhone and iPad playback, modal Mac playback, and edge-to-edge horizontal shelves with aligned content margins
- Adaptive light/dark favorite controls and uninterrupted iPhone playback when rotating between compact and split layouts
- A single app-owned iOS close control throughout preparation and playback, plus isolated custom error screens without AVKit error overlays
- Immediate cancellation and dismissal while an iPhone, Mac, or Apple TV stream is still preparing
- Privacy manifest with the required reason for app-local preferences
- Bilingual privacy and support documents linked from the app
- Copy-ready App Store metadata and release-readiness checklist
- Generic `LoadableViewModel` base shared by the Countries, Favorites, Channel Grid, and Home ViewModels
- `NavigationTile` and `TVOSChannelTile` platform-specific interaction views
- `AudioSessionCoordinator` for iOS audio-session interruption handling
- macOS arrow controls on horizontal carousels for mouse-only scrolling

### Changed

- Mapper accepts HTTP or HTTPS stream URLs while logos stay HTTPS-only, backed by a narrowly scoped `NSAllowsArbitraryLoadsForMedia` ATS exception
- `PlayerViewModel` rewritten around a dedicated `PlaybackAttempt` with 15-second preparation and 20-second stall timeouts
- Channel logos load through SwiftUI `AsyncImage` and the shared `URLCache`
- iOS and macOS navigation unified under `AppRootView`; tvOS retains its focus-aware root
- Feature ViewModels now inherit the shared load-state machinery from `LoadableViewModel`
- macOS Home carousels use fixed heights so horizontal shelves render correctly

[Unreleased]: https://github.com/HerniRG/WorldTV/commits/main
