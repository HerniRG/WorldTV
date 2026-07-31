# WorldTV Architecture

WorldTV uses pragmatic Clean Architecture. Phase 5 keeps the dependency direction established by Phase 1 and adds indexed catalog access, persistent caching, playback, local personalization, search, settings, and platform-native roots.

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
- `Data`: contains the HTTP client, iptv-org DTOs, mapping rules, filtering, joins, persistent cache, viewing history, favorites, and repository actors.
- `Features`: contains UI state and SwiftUI presentation. UI ViewModels are explicitly isolated with `@MainActor`.
- `Platform`: contains platform-native players, SwiftUI `AsyncImage` logo loading, the shared `LoadableViewModel` base, and platform navigation helpers.
- `Resources`: contains localized English and Spanish UI strings.

## Catalog loading

The API client fetches the six Phase 1 datasets concurrently. `IPTVOrgMapper` then:

1. Removes NSFW, blocked, and closed channels.
2. Builds the set of valid channel identifiers.
3. Accepts stream URLs over HTTP or HTTPS with a host, and logo URLs over HTTPS only.
4. Removes orphaned streams and logos.
5. Groups streams and logos by channel identifier.

`CatalogIndex` precalculates channels by identifier and country, countries by code, and the preferred logo for each channel. Views and ViewModels therefore do not repeatedly join tens of thousands of records.

The repository is an actor because it owns mutable in-memory catalog state. It reads a fresh persistent snapshot for up to 24 hours, refreshes from the network when required, and falls back to a stale snapshot if a refresh fails. Mapping, indexing, encoding, and decoding stay outside `MainActor`.

Logos load with SwiftUI's `AsyncImage` against the shared `URLCache`, so in-flight requests are cancelled automatically when cards leave the screen and cached responses are reused across screens.

## Playback

`ResolvePlayableStreamUseCase` resolves a channel into a bounded list of sources. HLS sources are preferred, followed by numeric quality. `PlaybackAttempt` inside `PlayerViewModel` owns the `AVPlayer` and its KVO observations, forwards required HTTP headers, and advances to the next source after a failure, a 15-second preparation timeout, or a 20-second stall timeout. On iOS, `AudioSessionCoordinator` activates the playback audio category and pauses or resumes playback when interruptions begin or end.

Playback settings are read at the presentation boundary and passed explicitly to the resolver. The resolver prefers HLS and then the stream closest to the selected quality. History is recorded only after playback actually starts. Home maps those identifiers back through the current catalog index, so removed channels disappear safely and recent channels retain current logos and availability.

## Personalization and search

Favorites are stored as stable channel identifiers behind an actor-backed repository. A shared `@MainActor` store keeps all visible feature screens consistent while persistence remains outside the UI layer.

Search runs locally against the indexed catalog and matches channel names, alternative names, countries, categories, and stream titles. `SearchViewModel` debounces text changes for 300 milliseconds and sends an immutable criteria value to the use case. Country, category, minimum quality, availability, geoblocking, and favorites are filters rather than view concerns.

Settings use small use cases for catalog refresh, cache removal, history removal, and cache metadata. User preferences use `AppStorage` because they are simple device-local values; repositories remain reserved for collections and operations that require explicit concurrency or mapping.

## Navigation

`AppRoute` remains the typed route passed between feature screens. A shared destination modifier resolves route identifiers using `AppContainer`, so platform roots do not duplicate construction or pass complete catalog objects.

- iPhone uses bottom tabs with an independent `NavigationStack` per section; iPad and macOS share a resizable `NavigationSplitView` rooted in `AppRootView`.
- tvOS uses its native top-level `TabView`; the selected section is restored with scene storage, while each tab retains its navigation and focus context.

Cards share semantic content but adapt interaction by platform: tvOS exposes an explicit focus ring and stable scale, macOS adds a restrained hover response, and Reduce Motion removes nonessential scaling animations. Platform-specific interactions are extracted into dedicated views such as `NavigationTile` (navigation link vs. top-level tvOS destination) and `TVOSChannelTile`, so feature views stay shared. Top-level platform dispatch is confined to the launch boundary and platform root files.

## Concurrency

The project compiles in Swift 6 mode with complete strict-concurrency checking. Domain values and DTOs are `Sendable`. Networking uses structured concurrency, and UI ViewModels are explicitly isolated to `@MainActor`.

## State management

Feature ViewModels use Observation and publish a single `Loadable<Value>` state for mutually exclusive idle, loading, loaded, empty, and failed conditions. A generic `LoadableViewModel` base owns the shared loading machinery (idle-guarded `loadIfNeeded`, `retry`, `refresh`, silent reload, task cancellation); feature ViewModels subclass it and provide only the load closure plus their own derived state. Simple device preferences use `AppStorage`; identifier collections and dated records use injected actor-backed repositories. Views start cancellable tasks but do not perform networking or catalog joins.

## Testing and continuous integration

Swift Testing covers DTO decoding, mapping and exclusion rules, indexes, cache freshness and fallback, playback source ordering, search filters, favorites, and history. Fixtures are local values under `WorldTVTests/Fixtures`, so unit tests do not depend on iptv-org availability.

The GitHub Actions workflow selects Xcode 26.6 on `macos-26`, performs unsigned iOS Simulator, tvOS Simulator, and macOS builds, and runs only the unit-test target. UI automation remains a separate smoke suite because simulator window automation can be less deterministic on hosted runners.

## Current trade-offs

- The mapper accepts HTTP or HTTPS stream URLs so more iptv-org streams are playable; logos remain HTTPS-only. ATS is scoped to the media exception (`NSAllowsArbitraryLoadsForMedia`) rather than disabling transport security for the whole app.
- tvOS still needs final App Icon and Top Shelf assets before distribution.
- Search works against the locally loaded catalog and intentionally caps one result page to keep presentation work bounded.
- Channel availability and rights are third-party properties; a successful catalog entry is not a guarantee that playback will work in every location.
