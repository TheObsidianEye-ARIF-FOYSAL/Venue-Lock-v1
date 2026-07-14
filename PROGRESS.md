# VenueLock — Session Progress Log

Running log of work done across Claude Code sessions in this repo. Newest entries on top.
Read this file first when resuming work here after a restart.

## 2026-07-14 session

### 17. Remaining bdapps-adjacent extras — LICENSE, store listing copy
- User is submitting VenueLock to bdapps and asked for the rest of the
  "extra work" MedRemind already has (GitHub Pages, actions, landing page,
  docs) — most of that was already done in the 2026-07-13 session (item 16
  below). Filled the two gaps found by diffing against `med_remind_v2`:
  - `LICENSE` — added, same attribution-required MIT-style terms as
    MedRemind's (copied verbatim, same author/copyright line).
  - `docs/APP_DESCRIPTION.md` — new: bdapps store listing copy (tagline,
    short/full description, category, keywords, screenshot checklist, links)
    since MedRemind had no direct equivalent to crib from (its
    `bdapps_production_request_email.md` is a different document — the
    email requesting production access, not listing copy). Linked from
    README.
- User manual: explicitly deferred by the user ("will be created later") —
  left a placeholder note in `APP_DESCRIPTION.md` pointing at the pattern to
  follow (`med_remind_v2/docs/medremind_user_guide.pdf`), not written yet.
- Not done: `scripts/` (MedRemind has `scripts/gen_icon.ps1`; VenueLock has
  no equivalent script yet and none was requested) and a `server/` dir
  (VenueLock's backend is `ARIF(VL)/`, a different name by earlier explicit
  choice — not renamed).

## 2026-07-13 session

### 16. CI / landing page / docs infrastructure — added (app + backend untouched)
- User asked to replicate the deployment infrastructure of a sibling project
  (MedRemind, `med_remind_v2`) — GitHub Actions + a landing page + root docs —
  while explicitly keeping the app code and the existing `ARIF(VL)/` PHP
  backend untouched, and giving the landing page its own visual identity
  rather than copying MedRemind's design.
- `.github/workflows/deploy-web.yml`: builds `app/` for web
  (`flutter build web --release --base-href /Venue-Lock-v1/app/`), assembles
  a `site/` combining `landing/` at the root and the web build under
  `site/app/`, deploys to GitHub Pages via
  `configure-pages`/`upload-pages-artifact`/`deploy-pages`. Triggers on push
  to `main` touching `app/**` or `landing/**`, plus manual dispatch.
- `.github/workflows/release-apk.yml`: builds a release APK on `v*` tags (or
  manual dispatch), renames it `VenueLock.apk`, publishes via
  `softprops/action-gh-release@v2` — floating `apk-latest` release when not
  triggered by a real tag, giving a stable
  `.../releases/latest/download/VenueLock.apk` URL.
- `landing/index.html`: new static landing page, brand-consistent with the
  app's indigo/amber palette (`app/assets/icon/app_icon_v2.svg`) but a
  distinct animated live-seat-grid hero concept, not a MedRemind reskin.
  Reused `app/web/icons/*` and `app/web/favicon.png` as source assets;
  `landing/manifest.json` points `start_url` at `./app/`.
- Root docs added: `README.md` (pitch, live demo/APK links, repo layout,
  local run instructions), `docs/PROJECT_OVERVIEW.md` (architecture/stack/
  security notes), `API_USAGE.md` (full app-service → `ARIF(VL)/*.php`
  endpoint map, including which backend files have no current caller).
- Not yet verified: the actual GitHub Actions runs (Pages deploy, tagged APK
  release) — need a push to `main` / a pushed tag to confirm end-to-end,
  can't be exercised locally. Also haven't yet actually run
  `flutter build web` / `flutter build apk --release` locally to sanity-check
  the exact commands the workflows use.

## 2026-07-09 session

### 15. App icon — resolved, wired into all platforms (follow-up to item 4)
- User picked icon v2 (`app/assets/icon/app_icon_v2.svg`, the ticket-stub +
  keyhole mark) to actually ship.
- **Rendering pipeline problem**: needed a 1024×1024 PNG master from the SVG
  since `flutter_launcher_icons` only accepts a raster `image_path`, not SVG.
  No system cairo lib on this Windows machine, so `cairosvg` / `svglib` +
  `reportlab` / `rlPyCairo` all failed at import with
  `OSError: no library called "cairo-2" was found` even after installing
  `pycairo` (its bundled DLL isn't discoverable by name via `ctypes.util`).
  **What worked**: wrap the SVG in a minimal HTML file and rasterize with
  headless Chrome (already installed at
  `C:\Program Files\Google\Chrome\Application\chrome.exe`):
  `chrome.exe --headless --disable-gpu --hide-scrollbars --screenshot=<abs-win-path.png> --window-size=1024,1024 file:///<abs-win-path.html>`.
  Gotchas: `--screenshot` needs an **absolute Windows path** (not a bash
  relative path / mixed-slash `$(pwd)` string) or it silently screenshots
  Chrome's own "file not found" error page instead of erroring out loudly;
  also needs `overflow:hidden` + explicit `width/height:1024px` on
  `html,body` or the scrollbar chrome gets baked into the image.
- Added `flutter_launcher_icons: ^0.14.3` to `pubspec.yaml` dev_dependencies,
  configured under a `flutter_launcher_icons:` block pointing at
  `assets/icon/app_icon_v2.png` for `android`, `ios`, `web` (with
  `background_color`/`theme_color: "#3730A3"`), and `windows` (256px). Ran
  `flutter pub get` then `dart run flutter_launcher_icons` — regenerated all
  `android/app/src/main/res/mipmap-*/ic_launcher.png`,
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` (+ new size variants
  it added), `web/icons/*.png` + `web/favicon.png` + `web/manifest.json`, and
  `windows/runner/resources/app_icon.ico`.
- Icon v1 (`app/assets/icon/app_icon.svg`) is still kept on disk per the
  earlier "do not delete" note, just not the one wired in.
- Not yet committed — changes are sitting in the working tree
  (`git status` shows the modified icon files + `pubspec.yaml`/`.lock`).
- Also wrote the user a Fable-5-ready text prompt (ticket+keyhole motif,
  indigo/amber palette, flat vector, 1024×1024) for generating a fresh icon
  concept if they want to explore further — not saved to a file, just given
  in-conversation.

## 2026-07-05 session (part 5)

### 13. Confirmed admin has no profile of its own (already done in part 4)
- Re-verified: no remaining references to `/admin/profile` or a
  `ProfileScreen` anywhere in the app. The only profile screen is
  `StudentProfileScreen` at `/student/profile`, reachable solely from the
  profile icon on the VenueLock role-picker.

### 14. MediaQuery-driven responsive layout
- Added `app/lib/app/responsive.dart`: `Responsive.horizontalPadding()`
  (grows with screen width instead of a fixed 16-24px everywhere),
  `Responsive.maxContentWidth`, and `ResponsiveScaffoldBody` (centers content,
  caps its width, applies the responsive horizontal padding) — a single
  source of truth for breakpoints instead of each screen inventing its own
  `width > 600 ? ... : 24` check.
- Applied it to: `CreateVenueScreen` (steps 1 & 3), `BookingScreen`,
  `EntryPassScreen`, `VenueDetailScreen`'s list, `VenueListScreen`'s list,
  `JoinScreen`, `VolunteerJoinScreen`, and `VolunteerStatusScreen` (which
  also got a `maxWidth: 420` cap on its status card so the message text
  doesn't stretch into unreadably long lines on a tablet).
- Seat grids (`SeatMapScreen`, `SeatReserveScreen`) already computed cell
  size from `MediaQuery.sizeOf(context).width`, so no change was needed
  there.

## 2026-07-05 session (part 4)

### 11. Unified profile — admin no longer has its own profile screen
- Deleted `features/admin/profile/profile_screen.dart` and the `/admin/profile`
  route. There is now exactly one profile screen
  (`features/student/profile/student_profile_screen.dart`, route
  `/student/profile`), reachable only from the profile icon on the VenueLock
  role-picker (`SplashScreen`).
- That screen always shows the local booking-details form (name/email/roll).
  If an admin happens to be signed in, it *also* shows everything that used
  to live behind `/admin/profile` — avatar, stats, appearance, change
  password, logout, unsubscribe, delete account — above a "BOOKING DETAILS"
  divider.
- Removed the tappable avatar/profile shortcut from `VenueListScreen`'s app
  bar (now a plain non-interactive avatar) — admin has to go back to the
  VenueLock screen to reach profile, same as every other role.

### 12. Role picker redesigned
- The cramped 3-column "Admin / Audience / Volunteer" row on `SplashScreen`
  felt flat. Replaced with a vertical stack of full-width `_RoleTile`s: each
  has its own gradient icon badge and glow color (indigo/amber/emerald),
  title + subtitle, a trailing arrow chip, a press-scale animation, and a
  staggered fade+slide-in on entry.

## 2026-07-05 session (part 3)

### 8. Local student profile, prefilled/editable booking info — added
- New `app/lib/core/services/student_profile_service.dart` (SharedPreferences-
  backed `ChangeNotifier`): stores name/email/roll locally since Audience has
  no server account. Registered as a provider in `main.dart`.
- New screen `app/lib/features/student/profile/student_profile_screen.dart`
  (route `/student/profile`) to view/edit it.
- A profile icon on `SplashScreen` opens it. (Originally also routed admins to
  a separate `/admin/profile`, but that screen was deleted in part 4 below —
  everyone now shares this one screen.)
- `BookingScreen` now prefills name/email/roll from the saved profile on
  load, saves whatever was typed back to the profile on successful booking,
  and has an "Edit Profile" link next to the form header.

### 9. Real camera QR scanning for admin check-in — added
- The old `ScannerScreen` had no actual camera scanning; it was a "Simulated
  Scanner" placeholder where the admin manually tapped a name in a list.
- Added `mobile_scanner` dependency, camera permission in
  `android/app/src/main/AndroidManifest.xml` and `NSCameraUsageDescription`
  in `ios/Runner/Info.plist`.
- New shared widget `app/lib/features/shared/qr_scan_view.dart` wraps
  `MobileScanner` with a 2s debounce so a code held in frame doesn't fire
  repeatedly.
- `ScannerScreen` now shows a live camera feed; scanning an entry pass QR
  (format `venueId::qrToken`, matching what `EntryPassScreen` encodes)
  validates the venueId and calls the existing check-in flow. The manual
  tap-to-check-in list stays below as a fallback/manual-override path.

### 10. Volunteer role — added
- New DB table `volunteers` (`ARIF(VL)/venuelock_db.php`): id, venue_id,
  name, phone, status (pending/approved/rejected), device_token, timestamps.
- New endpoints: `venuelock_volunteer_apply.php` (apply with a venue's 6-char
  access code + name/phone, returns a per-device token),
  `venuelock_volunteer_status.php` (poll approval status),
  `venuelock_volunteer_list.php` / `venuelock_volunteer_review.php`
  (admin-session + venue-ownership checked, list/approve/reject),
  `venuelock_volunteer_checkin.php` (mirrors `venuelock_checkin.php` but
  authenticates via the volunteer's device token + approved status instead
  of an admin session, scoped to just that venue).
- Flutter: `core/services/volunteer_service.dart` (REST client + local
  persistence of the active application, so a volunteer's pending/approved
  state survives an app restart — same pattern as item 6's pass storage).
  New screens under `features/volunteer/`: `volunteer_join_screen.dart`
  (apply), `volunteer_status_screen.dart` (polls every 4s, auto-routes to
  the scanner once approved), `volunteer_scanner_screen.dart` (camera scan
  reusing `QrScanView`). Admin side:
  `features/admin/venue_detail/volunteer_review_screen.dart` (route
  `/admin/venue/:id/volunteers`, linked from a new button on
  `VenueDetailScreen`) to approve/reject applicants.
- `SplashScreen` role picker now has three cards: Admin / Audience /
  Volunteer.

## 2026-07-05 session (part 2)

### 5. Venue data leaking from one admin account to the next after logout/login — fixed
- **Symptom**: User1 creates a venue, logs out; User2 logs in immediately after
  and sees User1's venues.
- **Root cause**: `AppState._pollVenues()` (`app/lib/core/services/app_state.dart`)
  is called on a 4s `Timer.periodic` and unconditionally overwrites `_venues`
  with whatever response arrives — it never checked whether the session that
  started the request was still the active one. A slow in-flight request for
  User1's phone/token could resolve *after* User2 had already logged in and
  reset state, clobbering User2's fresh (empty) venue list with User1's data.
  The backend (`ARIF(VL)/venuelock_venue_list.php`) was already correctly
  scoped by `admin_phone` — this was purely a client-side stale-response race.
- **Fix**: added a `_syncGeneration` counter, bumped on every `startSync`/
  `stopSync`. Each `_pollVenues` call captures the generation it was started
  with and discards its result if the generation has since changed.

### 6. Entry pass disappears after force-closing the app — fixed
- **Symptom**: after booking a seat and viewing the entry pass, force-closing
  and reopening the app loses the pass entirely, even though the booking is
  still valid server-side.
- **Root cause**: the pass was addressable only via in-memory route params
  (`/student/pass/:venueId/:seatId`) with zero local persistence — killing the
  app destroys the nav stack and there's no way back to that URL, and no
  backend endpoint exists to look bookings up by student email either.
- **Fix**: added `app/lib/core/services/pass_storage.dart` (SharedPreferences-
  backed) that saves `{venueId, seatId, venueName, seatLabel}` right after a
  successful booking (`booking_screen.dart`). `JoinScreen` now reads saved
  passes on load and shows a "My Entry Passes" list the student can tap back
  into at any time, even after a fresh app launch.

### 7. Admin seat reservation for guests — added
- New seat status `blocked` (previously only `available`/`booked` existed).
- New endpoint `ARIF(VL)/venuelock_seat_reserve.php` (session + venue-
  ownership checked) toggles a seat between `available` and `blocked`.
  `venuelock_seat_book.php`'s existing `WHERE status = 'available'` clause
  already excludes blocked seats from public booking with no changes needed.
- New admin screen `app/lib/features/admin/venue_detail/seat_reserve_screen.dart`
  (route `/admin/venue/:id/reserve`, linked from a new button on
  `VenueDetailScreen`) — tap an available seat to reserve it for a guest
  (prompts for a name/reason), tap a reserved seat to release it back.
  Student-facing `seat_map_screen.dart` now treats `blocked` the same as
  `booked` (greyed out, not tappable).

## 2026-07-04/05 session

### 1. OTP screen white-on-white text bug — fixed
- **Symptom**: on the OTP entry screen, typed digits were invisible.
- **Root cause**: global `InputDecorationTheme` in `app/lib/app/theme.dart` sets
  `filled: true` with no `fillColor`, so Material 3 defaults to a light
  `colorScheme.surfaceContainerHighest` fill. The 6 OTP box `TextField`s didn't
  override `filled`/`fillColor`, so that light fill painted over the dark glass
  `Container` background, hiding the white digit text.
- **Fix**: added `filled: false` to the OTP box `InputDecoration` in both:
  - `app/lib/features/admin/subscription/otp_screen.dart`
  - `app/lib/features/admin/auth/forgot_password_screen.dart` (has a duplicate
    `_OtpBox` widget for the forgot-password flow)

### 2. Admin venues screen — no back button + "boring" flat UI — fixed
- **Symptom**: tapping "Admin" on the role picker → `VenueListScreen`
  (`app/lib/features/admin/venue_list/venue_list_screen.dart`) had
  `automaticallyImplyLeading: false` and no leading action at all, so there was
  no way back. Also a plain white `AppBar`, inconsistent with the rest of the
  app's branded gradient look.
- **Fix**: added a back arrow (`context.go('/')` → role picker), gave the
  `AppBar` a brand-indigo gradient (`kIndigo` diagonal), white title/icons, and
  it now greets the admin by first name instead of a generic "VenueLock" label.

### 3. Crash: Audience → enter code → select a seat → app "stops working" — fixed
- Reproduced live by running the app on the user's connected Android phone
  (`flutter run -d <device>`) and capturing the real crash from the log —
  don't guess on crashes if a device is reachable.
- **Root cause**: global `FilledButtonThemeData` sets
  `minimumSize: Size.fromHeight(52)` (width = infinity), intended for full-width
  buttons that stretch inside a `Column`. The "Confirm Seat" button in
  `app/lib/features/student/seat_map/seat_map_screen.dart` (~line 228) sits
  directly in a `Row` next to an `Expanded` seat-info column with no width
  constraint of its own. The moment a seat is selected, that bottom bar
  appears and Flutter can't resolve an infinite-width button inside a `Row` —
  throws `BoxConstraints forces an infinite width` every frame.
- **Fix**: gave that button `style: FilledButton.styleFrom(minimumSize: const
  Size(140, 48))` to override the inherited infinite-width default.
- Not yet re-verified end-to-end on-device post-fix (needed a live venue/join
  code to click all the way through); `flutter analyze` is clean on the file.

### 4. App icon — in progress, awaiting user's verdict
- Wrote a general, reusable icon-design brief: `app/ICON_PROMPT.md`.
- Icon v1 (padlock + seat-row shackle, indigo gradient): user didn't like it.
  Kept at `app/assets/icon/app_icon.svg` — **do not delete**.
- Icon v2 (ticket stub with a keyhole punched through, amber glow behind, on a
  richer indigo→near-black gradient): `app/assets/icon/app_icon_v2.svg`.
  Waiting on user feedback before wiring either into the actual Android/iOS
  launcher icons (`android/app/src/main/res/mipmap-*`, currently generic
  `ic_launcher.png`).
- Both icons were designed by delegating to the `fable` model via the Agent
  tool (`model: "fable"`) per user's explicit request — user wants icon design
  work done by Fable 5 specifically, not by the main agent.
- Preview artifact of both icons side by side (session-scoped, may not survive
  session end): https://claude.ai/code/artifact/d5f00b83-b4e9-40f0-b3a8-57d773255727

## Environment notes worth remembering
- `flutter run -d windows` fails here — Developer Mode isn't enabled for
  symlink support (`Building with plugins requires symlink support`). Use the
  connected Android device instead: `RMX3241 (wireless)`, device id
  `adb-P75PHISKJNPRWGLJ-rbgtyQ._adb-tls-connect._tcp` (may change if
  reconnected — run `flutter devices` to confirm current id).
- Backend is a PHP REST API at `ARIF(VL)/` (not Firestore, despite some
  leftover comments in the code referencing Firestore/"FirestoreService" —
  those are stale naming, the actual client is `VenueService` in
  `app/lib/core/services/venue_service.dart` hitting
  `https://ruetandroiddevelopers.com/ARIF(VL)/*.php`).

## Not yet verified live (next session should do this first)
Everything in parts 2–5 above was built and passed `flutter analyze`, but
none of it has been exercised on the connected Android device yet. Before
trusting it, run through:
- Log in as admin A, create a venue, log out, log in as admin B — confirm B
  never sees A's venues (item 5).
- Book a seat, force-close the app, reopen it, tap "My Entry Passes" from
  the Join screen — confirm the pass still opens (item 6).
- As admin, open a venue → "Reserve Seats for Guests", reserve a seat, then
  confirm the Audience seat map shows it as unavailable (item 7).
- Fill in the profile screen once, then start a booking — confirm the form
  prefills, and that editing it there updates future bookings (item 8).
- Actually point the phone camera at a generated entry pass QR in
  `ScannerScreen` — this is the first real test of `mobile_scanner` in this
  app; check the camera permission prompt appears and check-in fires
  (item 9).
- Full volunteer loop: apply from the Volunteer role card, approve from
  admin's new "Volunteer Applications" screen, confirm the volunteer's app
  auto-navigates to its own camera scanner and can check attendees in
  (item 10).
- Eyeball the role-picker tiles and a couple of forms (Booking, Create
  Venue) on both a small phone and a tablet-sized emulator to confirm the
  new `Responsive` padding/width caps (item 14) actually look intentional,
  not just "not broken."

## Known rough edges not yet addressed
- `VenueService.getVenues`, `getVenueByCode`, `getVenueById`, and `getSeats`
  (in `app/lib/core/services/venue_service.dart`) have no try/catch, unlike
  `bookSeat`/`checkIn` which do. `getSeats` in particular is called directly
  (no error handling at the call site) from `BookingScreen._loadData` and
  `EntryPassScreen._load` via `Future.wait` — a network hiccup there would
  throw an unhandled exception. Not yet confirmed as a real bug the user has
  hit, but worth hardening to match the pattern used elsewhere in the file.
