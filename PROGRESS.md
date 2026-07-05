# VenueLock — Session Progress Log

Running log of work done across Claude Code sessions in this repo. Newest entries on top.
Read this file first when resuming work here after a restart.

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
- A profile icon on `SplashScreen` (the Admin/Audience/Volunteer role picker)
  opens it — or `/admin/profile` instead if an admin is currently logged in.
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

## Known rough edges not yet addressed
- `VenueService.getVenues`, `getVenueByCode`, `getVenueById`, and `getSeats`
  (in `app/lib/core/services/venue_service.dart`) have no try/catch, unlike
  `bookSeat`/`checkIn` which do. `getSeats` in particular is called directly
  (no error handling at the call site) from `BookingScreen._loadData` and
  `EntryPassScreen._load` via `Future.wait` — a network hiccup there would
  throw an unhandled exception. Not yet confirmed as a real bug the user has
  hit, but worth hardening to match the pattern used elsewhere in the file.
