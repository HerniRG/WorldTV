# Data sources

WorldTV currently consumes the public JSON API maintained by [iptv-org](https://github.com/iptv-org/iptv).

## Endpoints

| Dataset | Endpoint | Purpose |
| --- | --- | --- |
| Channels | `https://iptv-org.github.io/api/channels.json` | Channel identity, names, country, categories, status |
| Streams | `https://iptv-org.github.io/api/streams.json` | Remote playback URLs and stream metadata |
| Logos | `https://iptv-org.github.io/api/logos.json` | Candidate channel artwork |
| Countries | `https://iptv-org.github.io/api/countries.json` | Region names, codes, flags, languages |
| Categories | `https://iptv-org.github.io/api/categories.json` | Category identifiers and names |
| Blocklist | `https://iptv-org.github.io/api/blocklist.json` | Channels excluded by the upstream project |

The languages endpoint is not currently loaded because the first product version does not expose language filtering.

## Relationships

- `Channel.id` matches `Stream.channel`.
- `Channel.id` matches `Logo.channel`.
- `Channel.country` matches `Country.code`.
- `Channel.categories` contains `Category.id` values.
- `Stream.feed` and `Logo.feed` may describe regional variants.

WorldTV builds a `CatalogIndex` after mapping so views do not repeatedly join large arrays.

## Inclusion policy

The mapper excludes:

- channels marked NSFW;
- channels present in the upstream blocklist;
- channels with a non-null closure date;
- malformed or non-HTTPS stream and logo URLs;
- streams and logos that cannot be associated with a known channel.

A channel can remain discoverable without a playable source so the interface can communicate that it is unavailable. WorldTV does not bypass geoblocking, DRM, authentication, or provider restrictions.

## Cache policy

The HTTP layer uses `URLCache`. The last valid mapped catalog is also encoded to a local cache with a 24-hour freshness window:

1. A fresh local snapshot is preferred.
2. An expired or absent snapshot triggers a network refresh.
3. If refresh fails and a stale snapshot exists, WorldTV returns the stale snapshot.
4. If neither network data nor a snapshot is available, the feature exposes a retryable error.

The cache can be removed from Settings. Favorites and history are separate local stores and are not included in the catalog snapshot.

## Availability and attribution

iptv-org and individual stream providers are third parties. Dataset inclusion does not guarantee uptime, quality, geographic access, or rights in a particular jurisdiction.

WorldTV does not claim ownership of channel names, logos, trademarks, metadata, or streams. See `DISCLAIMER.md` for the removal process and complete limitations.
