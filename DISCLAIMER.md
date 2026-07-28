# WorldTV disclaimer

WorldTV is an open-source client that reads public catalog metadata and asks Apple's media frameworks to play remote URLs. It does not host, mirror, cache, proxy, restream, sell, or provide access credentials for audiovisual content.

## Third-party content

Channel metadata and stream URLs are obtained from the public [iptv-org datasets](https://github.com/iptv-org/iptv). WorldTV is not affiliated with or endorsed by iptv-org, channel operators, broadcasters, trademark owners, or stream providers.

Channel names, logos, trademarks, broadcasts, metadata, and remote streams remain the property and responsibility of their respective owners. They are not covered by WorldTV's MIT license.

The presence of a channel or URL in a public dataset does not establish that:

- the stream will remain available;
- the stream is available in every country;
- playback is authorized in every jurisdiction;
- the stream is free from third-party rights;
- WorldTV or its contributors endorse the channel.

Users are responsible for complying with applicable laws and the terms imposed by content providers in their location.

## Technical limitations

Remote streams may fail without notice because of downtime, format changes, geoblocking, network policy, expiring URLs, or provider-side restrictions. WorldTV does not guarantee catalog accuracy, continuity, quality, legality, or fitness for a particular purpose.

WorldTV does not implement DRM bypasses, token extraction, location masking, private proxies, credential sharing, or access to deliberately protected content. Requests to add such functionality will not be accepted.

## Channel-removal requests

A rights holder or authorized representative can request review of a channel listing:

1. Open a [Channel removal request](https://github.com/HerniRG/WorldTV/issues/new?template=channel-removal.yml).
2. Identify the exact channel name, iptv-org channel identifier, country, and affected URL when it can be shared safely.
3. Explain the rights or authority supporting the request and provide a reliable way for the maintainer to verify the claim.
4. Do not publish personal documents, credentials, private tokens, or other sensitive evidence in the issue. State that private verification material is available instead.

WorldTV consumes an external catalog and cannot remove records from the upstream project directly. A verified request may result in an application-side exclusion and will also be referred to the relevant upstream removal process when appropriate.

Requests that concern an iptv-org record should also follow the [iptv-org contribution and issue process](https://github.com/iptv-org/iptv).

Security vulnerabilities are not channel-removal requests. Report them privately as described in [SECURITY.md](SECURITY.md).

## No warranty

The software is provided under the warranty disclaimer in the [MIT License](LICENSE). This document is informational and is not legal advice.
