# Security Policy

## Supported versions

Until the first public binary release, security fixes are applied to the `main` branch. After releases begin, only the latest published version will be supported unless a release note says otherwise.

## Report a vulnerability

Please report suspected vulnerabilities privately through [GitHub Security Advisories](https://github.com/xand0dev/VoidBar/security/advisories/new). Do not open a public issue for an undisclosed vulnerability.

Include, when possible:

- the affected version or commit;
- reproduction steps and the expected impact;
- relevant logs, screenshots, or a minimal proof of concept;
- whether the issue has already been disclosed elsewhere.

This is a volunteer-maintained project with no guaranteed response SLA. The maintainer will acknowledge a valid report when available, investigate it, and coordinate disclosure before publishing a fix.

## Security boundaries

VoidBar does not expose a listening network service or operate a project backend. It does make outbound requests for weather, configured TickTick feeds, and allow-listed Spotify artwork. See [PRIVACY.md](PRIVACY.md) for the complete network, storage, and permission map.

The TickTick iCal subscription URL may contain a secret token and is stored in macOS preferences. Reports involving exposed personal URLs, credentials, or other private data should be sanitized before sharing.

## Out of scope

- Gatekeeper warnings caused solely by locally built, ad-hoc-signed binaries;
- vulnerabilities in macOS or a third-party service without a VoidBar-specific impact;
- social engineering, spam, denial-of-service testing, or destructive testing;
- reports produced only by automated scanners without a reproducible impact.
