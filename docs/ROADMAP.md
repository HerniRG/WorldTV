# WorldTV roadmap

The roadmap communicates intent, not a release guarantee.

## Completed foundation

- Shared Swift 6 domain and data layers
- Structured iptv-org catalog ingestion and exclusions
- Persistent cache and degraded offline loading
- Home, countries, channel grids, logos, search, and filters
- AVPlayer playback with bounded fallback
- Favorites and recently watched history
- Native iPhone, iPad, Apple TV, and Mac navigation
- English and Spanish localization and core accessibility
- Open-source documentation and continuous integration
- Approved WorldTV visual identity and complete iOS/macOS App Icon sizes
- Layered Apple TV App Icon and standard/wide Top Shelf artwork
- Signed build, installation, and launch on a physical Apple TV
- Apple TV Home release screenshot

## Before the first distribution build

- Capture the remaining release screenshot matrix
- Complete playback, focus, VoiceOver, rotation, and window-resizing checks across physical devices
- Confirm store privacy details and legal metadata
- Review channel-removal handling with appropriate legal advice
- Tag the first release after CI is green

## Candidate follow-up work

- Network reachability as a user-facing signal when it adds value
- Language filtering after the catalog language relationship is implemented
- Optional independent playback window on macOS
- Expanded integration tests with deterministic injected catalog fixtures
- More granular application shortcuts and commands on macOS
- Additional localizations contributed by native speakers

## Out of scope

- Accounts, cross-device tracking, analytics, or advertising
- Hosting, mirroring, proxying, or retransmitting streams
- DRM bypass, private-token extraction, or geoblocking evasion
- Claims of real-world popularity without an auditable data source
