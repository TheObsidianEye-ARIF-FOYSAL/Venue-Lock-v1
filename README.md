# VenueLock

Cap attendance at an exact seat count. VenueLock lets an admin create a venue
with a fixed seat map, attendees book an exact seat and get a QR entry pass,
and admins/volunteers check people in with a live camera scan at the door —
no overbooking, no clipboard.

🔗 **Live demo:** https://theobsidianeye-arif-foysal.github.io/Venue-Lock-v1/
📱 **Android APK:** https://github.com/TheObsidianEye-ARIF-FOYSAL/Venue-Lock-v1/releases/latest/download/VenueLock.apk

## Features

- Seat-level booking against a live seat map (capacity enforced server-side)
- QR entry passes, persisted on-device (survive a force-close/restart)
- Live camera check-in (`mobile_scanner`) for admins and volunteers
- Admin seat reservation for guests/VIPs (blocked seats skip public booking)
- Volunteer role: apply per-venue with an access code, get approved, scan
  with a device-scoped token — no shared admin logins at the door
- Phone/OTP auth + subscription flow for admin accounts

## Repo layout

```
app/          Flutter app (Android/iOS/Web/Windows) — the product
ARIF(VL)/     PHP + SQLite REST backend, deployed at ruetandroiddevelopers.com
landing/      Static marketing/landing page, published via GitHub Pages
docs/         Project overview and other reference docs
.github/      CI: web deploy to GitHub Pages, tagged APK releases
```

## Running locally

```
cd app
flutter pub get
flutter run
```

The app talks to the already-deployed backend at
`https://ruetandroiddevelopers.com/ARIF(VL)` by default (see
`app/lib/core/services/*_service.dart`) — no local server needed to run the
app.

## Docs

- [`docs/PROJECT_OVERVIEW.md`](docs/PROJECT_OVERVIEW.md) — architecture, tech
  stack, security notes
- [`API_USAGE.md`](API_USAGE.md) — map of every app → backend network call
- [`app/AUTH_AND_SUBSCRIPTION.md`](app/AUTH_AND_SUBSCRIPTION.md) — auth &
  subscription flow details
- [`docs/APP_DESCRIPTION.md`](docs/APP_DESCRIPTION.md) — store listing copy
  (bdapps submission)
- [`PROGRESS.md`](PROGRESS.md) — running session log of work done in this repo

## License

MIT-style with attribution — see [`LICENSE`](LICENSE).
