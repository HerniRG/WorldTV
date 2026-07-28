# WorldTV Architecture

WorldTV uses pragmatic Clean Architecture. Phase 1 establishes the dependency direction without introducing protocols that do not provide a testing or isolation benefit.

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
- `Data`: contains the HTTP client, iptv-org DTOs, mapping rules, filtering, joins, and the repository actor.
- `Features`: contains UI state and SwiftUI presentation. UI ViewModels are explicitly isolated with `@MainActor`.
- `Resources`: contains localized English and Spanish UI strings.

## Catalog loading

The API client fetches the six Phase 1 datasets concurrently. `IPTVOrgMapper` then:

1. Removes NSFW, blocked, and closed channels.
2. Builds the set of valid channel identifiers.
3. Accepts only HTTPS stream and logo URLs with a host.
4. Removes orphaned streams and logos.
5. Groups streams and logos by channel identifier.

The repository is an actor because it owns mutable in-memory catalog state. This prevents duplicate mutation and keeps data work outside `MainActor`.

## Concurrency

The project compiles in Swift 6 mode with complete strict-concurrency checking. Domain values and DTOs are `Sendable`. Networking uses structured concurrency, and only `LaunchViewModel` is `@MainActor`.

## Current trade-offs

- The repository has only an in-memory cache. Persistent cache and expiration belong to Phase 2.
- The mapper accepts HTTPS only. Any narrowly scoped transport exception must be justified and documented later.
- The launch screen is intentionally temporary; final navigation and platform-specific roots belong to Phase 4.
- tvOS still needs final App Icon and Top Shelf assets before distribution.
