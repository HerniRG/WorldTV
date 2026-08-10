# CloudKit setup

This branch adds an optional private CloudKit replica for favorites and playlist sources. The app continues to use local storage when iCloud is unavailable.

## Developer setup

1. In Apple Developer Certificates, Identifiers & Profiles, open the `hrgapps.WorldTV` App ID.
2. Enable iCloud and CloudKit for the App ID.
3. In Xcode, select the `WorldTV` target and add the iCloud capability with the CloudKit service.
4. Create or select the container `iCloud.hrgapps.WorldTV` in CloudKit Console.
5. Build and run the app on two devices signed into the same Apple Account.

The first read or write creates the `WorldTVProfile` record in the private database. No app account is required. CloudKit errors are intentionally ignored by the sync wrappers so the local app remains usable.

## Current proof-of-concept behavior

- Favorites are merged by channel identifier.
- Playlist sources are merged by normalized URL.
- Adding data on one device publishes it to the other device.
- The local store remains available offline.

Deletion conflict handling and a visible sync status are left for the next iteration, after validating the basic two-device flow.
