# Release checklist

## Automated and repository checks

- [x] Cross-platform App Icon catalog
- [x] Layered tvOS icon and Top Shelf assets
- [x] Privacy manifest with no tracking or collected-data declarations
- [x] Required-reason declaration for app-local `UserDefaults`
- [x] Privacy policy and support document accessible from the app
- [x] Export-compliance key declares only exempt system encryption
- [x] English and Spanish App Store metadata draft
- [x] CI builds iOS Simulator, tvOS Simulator, and macOS
- [x] Offline unit tests

## App Store Connect

- [ ] Create the app record using bundle ID `hrgapps.WorldTV`
- [ ] Confirm that the name WorldTV is available
- [ ] Add iOS, macOS, and tvOS platform versions
- [ ] Paste localized metadata from `docs/APP_STORE_METADATA.md`
- [ ] Select “No data collected” after a final source audit
- [ ] Paste the tvOS privacy-policy text and set the iOS/macOS privacy URL
- [ ] Add current support and marketing URLs
- [ ] Complete age-rating questionnaire after editorial review
- [ ] Complete content-rights declaration after legal review
- [ ] Choose storefront availability consistent with stream rights
- [ ] Confirm Digital Services Act trader status for EU distribution
- [ ] Confirm agreements, tax, and banking state where applicable

## Screenshots

- [ ] iPhone 6.9-inch portrait: 1260×2736, 1290×2796, or 1320×2868
- [ ] iPad 13-inch landscape: 2752×2064 or 2732×2048
- [x] Apple TV: 1920×1080
- [ ] Mac 16:10: 1280×800, 1440×900, 2560×1600, or 2880×1800
- [ ] Check every PNG is opaque and contains no personal information
- [ ] Add at least one screenshot and no more than ten per required display

## Physical-device acceptance

- [x] Signed build installs and launches on a physical Apple TV
- [ ] Apple TV: verify every tab, visible focus, back behavior, player controls, retry, and fallback
- [ ] iPhone: verify portrait, landscape player, AirPlay, interruption, and offline state
- [ ] iPad: verify split navigation, rotation, multitasking sizes, and player
- [ ] Mac: verify minimum/default/large window sizes, keyboard navigation, toolbar, and player
- [ ] VoiceOver smoke test on every platform
- [ ] Reduce Motion and increased text-size smoke test
- [ ] Clear-data controls and cold-launch cache fallback

## Archive and submission

- [ ] Increment build number for every uploaded archive
- [ ] Archive Release for each submitted platform
- [ ] Validate archives in Xcode Organizer
- [ ] Confirm privacy report contains only expected entries
- [ ] Upload to App Store Connect/TestFlight
- [ ] Perform internal TestFlight smoke test
- [ ] Attach any review demo video needed to explain variable third-party streams
- [ ] Select manual release for version 1.0
- [ ] Tag `v1.0.0` only after approval and green CI

## Authoritative Apple references

- [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [App privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
