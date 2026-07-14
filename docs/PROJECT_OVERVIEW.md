# VenueLock — Project Overview

## What it does

VenueLock caps event attendance at an exact seat count. An admin creates a
venue with a fixed seat map; attendees join with a venue code and book a
specific seat (never oversold); each booking produces a QR entry pass stored
on-device; admins and approved volunteers scan those passes at the door with
the phone's own camera to check people in live.

Three roles share one app:

- **Admin** — creates/configures venues, reserves seats for guests, reviews
  and approves volunteers, scans at the door
- **Audience** — joins with a venue code, books a seat, holds the entry pass
- **Volunteer** — applies per-venue with an access code, gets approved, scans
  with a device-scoped token (no shared admin login at the gate)

## Tech stack

- **App**: Flutter (Android, iOS, Web, Windows), `provider` for state,
  `go_router` for navigation, `mobile_scanner` for camera QR scanning,
  `qr_flutter` for generating passes, `SharedPreferences` for local
  persistence (profile, saved passes, volunteer session).
- **Backend**: plain PHP + SQLite REST API (`ARIF(VL)/`), no framework,
  deployed by copying files to a shared PHP host
  (`ruetandroiddevelopers.com`). Session-token auth for admins, per-device
  tokens for volunteers. OTP delivery goes through a BDApps carrier SMS/USSD
  SDK vendored alongside the endpoints.
- **Landing page**: static HTML/CSS/JS (`landing/`), no build step, deployed
  alongside the Flutter web build to one GitHub Pages site.
- **CI**: GitHub Actions — `deploy-web.yml` builds `app/` for web and
  assembles it with `landing/` into a single Pages site (landing at `/`, app
  at `/app/`); `release-apk.yml` builds a release APK on version tags (or
  manual dispatch) and publishes it via GitHub Releases, giving the landing
  page a stable `/releases/latest/download/VenueLock.apk` link.

## Repo layout

```
app/          Flutter app — the actual product
ARIF(VL)/     PHP/SQLite backend (external host, not built by CI)
landing/      Static marketing page, published via GitHub Pages
docs/         This file and other reference docs
.github/      CI workflows
```

## Security notes

- Admin session tokens and volunteer device tokens are the only auth
  primitives — no OAuth/JWT, matching the low-infra PHP backend.
- `ARIF(VL)/venuelock_seat_book.php`'s `WHERE status = 'available'` clause is
  what actually prevents overbooking/double-booking of a reserved seat;
  client-side seat-map state is a read model, not the source of truth.
- The client polls venue/seat state on a timer rather than using push —
  `AppState` guards against stale-response races across login/logout with a
  `_syncGeneration` counter (see `app/PROGRESS.md` history for the incident
  that motivated this).
- See [`API_USAGE.md`](../API_USAGE.md) for the full endpoint map, including
  which backend files are dead code as of this writing.
