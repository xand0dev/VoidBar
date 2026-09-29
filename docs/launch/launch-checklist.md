# Launch checklist

## Before any post

- [ ] The latest release page shows the DMG and `.sha256` file, and both download.
- [ ] A clean Mac (or a new macOS user account) can install from the DMG by following the README, including **Open Anyway**.
- [ ] The README walkthrough, install steps, and known limitations match the release.
- [ ] The repository social preview is set (Settings → General → Social preview → `docs/assets/social-preview.png`).
- [ ] Issues and Discussions are open, and you can answer questions for the next several hours.
- [ ] Replace every `<PLACEHOLDER>` in the copy you use.

## Recommended sequence

1. **Show HN** on a weekday morning, US Eastern time. Stay in the thread and answer technical questions.
2. **r/MacApps** a day or two later, after incorporating anything Hacker News surfaced.
3. **Technical post** (personal blog, dev.to, or Swift Forums' community showcase) once the questions from the first two show what developers found interesting. Link to it from later discussions instead of repeating yourself.
4. **Product Hunt** only after the above, when install friction and first-launch questions are well understood. Launch at 00:01 Pacific time.
5. **r/macOS** only on its self-promotion day (see below).

## Community rules to re-check on the day

- **r/MacApps:** posts by developers must disclose that you are the developer and follow the subreddit's current post template (the draft uses Problem / Comparison / Pricing / Changelog / AI disclosure). New or low-karma accounts are often filtered — check the current account-age and karma requirement in the sidebar and wiki, and build history by participating before posting. One post per release; do not repost to bump.
- **r/macOS:** self-promotion has historically been limited to Saturdays. Confirm the current rule in the sidebar before posting, and skip it if the rule has changed to a ban.
- **Hacker News:** "Show HN" is for things people can try right now; the release download satisfies that. Do not ask anyone to upvote or comment, and do not share the link to solicit votes.
- **Product Hunt:** do not ask for upvotes in the listing, comments, or outside messages. Ask for feedback instead.
- **Everywhere:** no star-for-star exchanges, bought engagement, sock-puppet accounts, or automated replies. Answer criticism directly, including about the missing notarization.

## Honest answers to prepare

- **Why is it not notarized?** No Apple Developer ID yet. The build is ad-hoc signed, built from the tag by GitHub Actions with a provenance attestation, and ships with a SHA-256 checksum. Building from source is one command.
- **Why does a notch app need perl?** macOS 15.4+ only answers trusted clients for system Now Playing data; `/usr/bin/perl` is a platform binary without library validation that can host the small helper. If it is blocked, VoidBar falls back to scripting Apple Music and Spotify.
- **Intel?** The published build is Apple Silicon only; building from source on Intel is untested.
- **Network access?** See PRIVACY.md: weather, TickTick, Spotify artwork, and Apple's translation assets only.

## Placeholders

| Placeholder | Fill in with |
| --- | --- |
| `<RELEASE_URL>` | https://github.com/xand0dev/VoidBar/releases/latest |
| `<REPO_URL>` | https://github.com/xand0dev/VoidBar |
| `<TECH_POST_URL>` | The published technical post, once it exists |
| `<YOUR_NAME>` | The name you post under |
