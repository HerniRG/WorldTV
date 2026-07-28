# WorldTV Architecture

WorldTV uses pragmatic Clean Architecture. Phase 3 keeps the dependency direction established by Phase 1 and adds indexed catalog access, persistent caching, playback, and local viewing history.

```text
SwiftUI feature
    ↓
Use case
    ↓
Domain repository protocol
    ↓
Data repository → IPTVOrg API client → HTTP client
```

## Layers

- `App`: constructs dependencies explicitly in `AppContainer`.
- `Domain`: contains `Sendable` entities, repository contracts, load state, and use cases. It does not import SwiftUI, AVKit, or networking implementations.
- `Data`: contains the HTTP client, iptv-org DTOs, mapping rules, filtering, joins, persistent cache, viewing history, and repository actors.
- `Features`: contains UI state and SwiftUI presentation. UI ViewModels are explicitly isolated with `@MainActor`.
- `Platform`: contains the cancellable image loader, platform image conversion, and native player adapters.
- `Resources`: contains localized English and Spanish UI strings.

## Catalog loading

The API client fetches the six Phase 1 datasets concurrently. `IPTVOrgMapper` then:

1. Removes NSFW, blocked, and closed channels.
2. Builds the set of valid channel identifiers.
3. Accepts only HTTPS stream and logo URLs with a host.
4. Removes orphaned streams and logos.
5. Groups streams and logos by channel identifier.

`CatalogIndex` precalculates channels by identifier and country, countries by code, and the preferred logo for each channel. Views and ViewModels therefore do not repeatedly join tens of thousands of records.

The repository is an actor because it owns mutable in-memory catalog state. It reads a fresh persistent snapshot for up to 24 hours, refreshes from the network when required, and falls back to a stale snapshot if a refresh fails. Mapping, indexing, encoding, and decoding stay outside `MainActor`.

Logos are loaded through an injected actor backed by a dedicated `URLSession` and `URLCache`. SwiftUI tasks cancel image requests when cards leave the screen.

## Playback

`ResolvePlayableStreamUseCase` resolves a channel into a bounded list of sources. HLS sources are preferred, followed by numeric quality. `PlayerViewModel` owns `AVPlayer`, observes item and time-control state, forwards required HTTP headers, and advances to the next source after a failure or a 15-second preparation timeout.

Successful preparation records the channel through an injected history repository. Home maps those identifiers back through the current catalog index, so removed channels disappear safely and recent channels retain current logos and availability.

## Concurrency

The project compiles in Swift 6 mode with complete strict-concurrency checking. Domain values and DTOs are `Sendable`. Networking uses structured concurrency, and UI ViewModels are explicitly isolated to `@MainActor`.

## Current trade-offs

- The mapper accepts HTTPS only. Any narrowly scoped transport exception must be justified and documented later.
- The shared `NavigationStack` is intentional at this stage; final platform-specific roots belong to Phase 4.
- tvOS still needs final App Icon and Top Shelf assets before distribution.
