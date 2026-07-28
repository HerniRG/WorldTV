# Security policy

## Supported versions

WorldTV is pre-release software. Security fixes are applied to the latest commit on `main`; older snapshots are not maintained as supported releases.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability.

Use GitHub's private [Report a vulnerability](https://github.com/HerniRG/WorldTV/security/advisories/new) form and include:

- affected commit or version;
- impacted Apple platforms;
- reproducible steps or a minimal proof of concept;
- expected security impact;
- suggested mitigation, if known.

Do not include live credentials, private tokens, personal information, or copyrighted stream content. A maintainer will acknowledge a complete report as soon as practical, assess it, and coordinate disclosure after a fix is available.

## In scope

- unsafe handling of remote catalog or media metadata;
- unintended disclosure of local favorites, history, or cache data;
- code execution, sandbox escape, or privilege escalation caused by WorldTV;
- insecure network behavior introduced by the app;
- dependency or CI supply-chain concerns.

Channel availability, broken streams, geoblocking, and ownership disputes are not security vulnerabilities. Use the process in `DISCLAIMER.md` for channel-removal requests.
