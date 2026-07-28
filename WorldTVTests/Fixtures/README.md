# Test fixtures

`IPTVOrgFixtures.swift` contains deliberately small, deterministic representations of iptv-org payloads.

Fixtures must:

- stay offline and never call production endpoints;
- use reserved `example.com` URLs;
- cover valid, NSFW, closed, blocklisted, insecure, and orphaned records;
- contain no live tokens, credentials, or copyrighted media;
- remain small enough that the mapping rules are obvious during review.

Feature-specific fixtures may remain in their test file when they are used by only one suite.
