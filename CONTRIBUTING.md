# Contributing to WorldTV

Thanks for helping improve WorldTV.

## Before opening a change

- Use GitHub Issues for reproducible bugs and focused feature proposals.
- Use the dedicated form for channel-removal requests.
- Follow `SECURITY.md` for vulnerabilities; do not disclose them publicly.
- Keep changes within WorldTV's legal scope. DRM bypasses, private-token extraction, geoblocking evasion, tracking, and deliberate pay-TV access are out of scope.

## Development setup

1. Use macOS 26.5 or newer and Xcode 26.6 or newer.
2. Fork and clone the repository.
3. Create a focused branch from `main`.
4. Open `WorldTV.xcodeproj` and build the `WorldTV` scheme.

No third-party dependency installation or credentials are required.

## Code expectations

- Preserve the Domain → Data → Features dependency direction.
- Use Swift 6 strict concurrency, structured concurrency, and cancellation.
- Isolate UI ViewModels to `MainActor`.
- Keep networking and catalog joins outside SwiftUI views.
- Avoid force unwraps, force tries, global mutable singletons, ignored errors, and production `print` calls.
- Add localized English and Spanish strings for visible text.
- Preserve VoiceOver, Dynamic Type, Reduce Motion, macOS hover, and tvOS focus behavior.
- Do not add dependencies, transport-security exceptions, analytics, advertisements, or permissions without prior discussion.
- Do not edit `project.pbxproj` manually unless the project structure cannot express the change automatically.

## Tests

Add or update small offline fixtures for domain and data behavior. Unit tests must not call live iptv-org endpoints.

Run:

```sh
xcodebuild \
  -project WorldTV.xcodeproj \
  -scheme WorldTV \
  -destination 'platform=macOS' \
  -only-testing:WorldTVTests \
  test
```

Build each affected destination before opening a pull request. Changes to shared UI or domain code should compile for iOS Simulator, tvOS Simulator, and macOS.

## Pull requests

Describe:

- the user-visible outcome;
- the platforms affected;
- architectural or legal trade-offs;
- tests and builds performed;
- screenshots for visual changes.

Keep a pull request focused and avoid unrelated formatting or generated-file churn. By contributing, you agree that your contribution is licensed under the repository's MIT License.
