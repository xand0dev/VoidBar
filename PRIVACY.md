# Privacy

VoidBar is local-first and has no analytics, advertising, user accounts, or project-operated backend. This document describes every intentional network connection, stored data category, and system permission in the current codebase.

## Network connections

| Feature | Destination | Data sent | When |
| --- | --- | --- | --- |
| Weather location | `https://ipapi.co/json/` | The requester's public IP is visible to the service as part of a normal HTTPS request. | After the Weather tab is first opened and every 30 minutes afterward while VoidBar runs. |
| Weather forecast | `https://api.open-meteo.com/` | Approximate latitude and longitude returned by the location service. | After a successful weather-location request. |
| TickTick | The iCal URL entered in settings | A normal HTTPS request to that URL; the URL itself may contain a private subscription token. | After configuration and every 15 minutes while VoidBar runs. |
| Spotify artwork | `i.scdn.co`, `mosaic.scdn.co`, or `lineup-images.scdn.co` | A normal HTTPS image request. Cookies and URL caching are disabled. | When compatible Spotify artwork is available. |
| Translation assets | Apple-managed services | Managed by macOS, not by VoidBar. | macOS may download a language pack when needed. |

VoidBar does not send notes, snippets, clipboard contents, file-shelf paths, calendar events, translations, system statistics, or telemetry to a VoidBar server. There is no VoidBar server.

## Local data

| Data | Storage | Lifetime |
| --- | --- | --- |
| Clipboard history | Process memory only | Cleared when VoidBar quits; concealed password-manager entries are ignored. |
| Copied images | `~/Pictures/VoidBar/` | Kept until the user disables saving or moves the folder contents to Trash from the menu bar. |
| File shelf | File paths in macOS preferences | Kept across launches; source files are never copied or uploaded by the shelf. |
| Notes | `~/Library/Application Support/VoidBar/notes.json` | Kept until deleted in the app. The file is set to owner-only permissions where supported. |
| Snippets | `~/Library/Application Support/VoidBar/snippets.json` | Kept until deleted in the app or file. The file is set to owner-only permissions where supported. |
| Teleprompter text | macOS preferences | Kept across launches. |
| Pomodoro totals, tab layout, and settings | macOS preferences | Kept across launches. |
| TickTick subscription URL | macOS preferences | Kept until removed from settings. Treat this URL as a secret because it may contain an access token. |

Local files and macOS preferences are not encrypted by VoidBar. Protection depends on the user's macOS account, disk encryption, backups, and device security.

## Permissions

- **Calendar:** requested only after the user chooses to grant calendar access from the Calendar pane.
- **Automation / Apple Events:** macOS may request access when AppleScript fallback controls Apple Music or Spotify.
- **Accessibility:** only needed by the system-wide media-key fallback when direct player control is unavailable.
- **Notifications:** requested when the user starts a Pomodoro timer so VoidBar can announce completion.
- **Launch at Login:** enabled or disabled explicitly from the menu bar.

VoidBar does not request Screen Recording permission.

## Third-party policies

Remote requests are governed by the privacy policies of the service receiving them: ipapi, Open-Meteo, TickTick, Spotify, or Apple. Avoid opening the Weather tab or configuring TickTick if you do not want those connections. Once Weather has been opened, it continues refreshing every 30 minutes until VoidBar quits.

## Questions and changes

Privacy issues can be reported through [GitHub Issues](https://github.com/xand0dev/VoidBar/issues). Security-sensitive reports should use the private process in [SECURITY.md](SECURITY.md). Material behavior changes should update this file in the same pull request.
