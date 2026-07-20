# VenueLock — Session Progress Log

Running log of work done across Claude Code sessions in this repo. Newest entries on top.
Read this file first when resuming work here after a restart.

## 2026-07-21 session (continued — item 37)

### 37. Profile split from one long screen into a hub + 4 dedicated screens
- Follow-up to item 36. User asked for a hub-and-spoke structure instead of
  one long scroll: Personal Details stays inline on the main Profile
  screen; Admin Account, My Bookings, and Volunteer each become their own
  screen reached by tapping a row; Change Password/Logout/Unsubscribe/
  Delete Account move to one card at the very end of the main Profile
  screen (not inside the Admin sub-screen).
- New shared file `lib/features/student/profile/profile_widgets.dart`:
  public (non-underscore) versions of the small pieces every profile screen
  needs — `ProfileSubScaffold` (gradient bg + back arrow + title, shared
  chrome for all 4 sub-screens), `ProfileScrollBody` (centers content at the
  same max-width as the hub), `ProfileEmptyState`, `CardDivider`,
  `MiniStat`, `StatTile`, `SettingsRow` (now takes an optional `subtitle`,
  used both for plain actions and for nav rows), `SubLabel`, `PassTile`.
- New screens, each self-contained (loads its own data in `initState`
  rather than receiving it from the hub, since go_router doesn't cleanly
  carry non-primitive objects through route params):
  - `admin_console_screen.dart` → **Admin Console** — subscribed number,
    venue stats, "Manage Venues". No account actions here anymore.
  - `entry_passes_screen.dart` → **Entry Passes** — upcoming/past bookings
    (same logic as the old inline `_AudienceSection`, just self-loading).
  - `volunteering_screen.dart` → **Volunteering** — active application +
    live status (self-loading, same as the old inline `_VolunteerSection`).
  - `appearance_screen.dart` → **Appearance** — palette + light/dark/system,
    unchanged content, now full-screen instead of an inline card.
- `router.dart`: 4 new routes nested under the existing profile route —
  `/student/profile/console`, `/student/profile/passes`,
  `/student/profile/volunteering`, `/student/profile/appearance`.
- `student_profile_screen.dart` (the hub) rewritten much shorter: header
  (unchanged multi-badge logic from item 36) → Personal Details card
  (unchanged) → one "SECTIONS" card of `SettingsRow` nav rows (each with a
  live subtitle — e.g. Entry Passes shows "3 bookings" or "No bookings
  yet") →, only for a logged-in admin, one "ACCOUNT" card at the bottom
  with Change Password/Logout/Unsubscribe/Delete Account. The hub still
  loads `_volunteerApp`/`_passes` itself (lighter than before — no longer
  fetches live volunteer status, just whether an application exists) purely
  to drive the header badges and nav-row subtitles; each sub-screen
  independently loads full detail when opened.
- `flutter analyze` clean across all 6 touched/new files. Not yet run on a
  device — this is a navigation-structure change on top of item 36's visual
  rewrite, worth a full click-through: each of the 4 nav rows actually
  opens its screen, back arrows return to the hub, and the account actions
  (especially Unsubscribe/Delete Account, which navigate to the subscribe
  gate on success) still work correctly from their new location.

## 2026-07-21 session (continued — item 36)

### 36. Profile screen — full redesign (was the messiest screen in the app)
- User feedback was blunt: profile "looks unrelated," its UI is "disgusting,"
  and having user details/admin account/manage venues/change password/
  logout/unsubscribe/delete account/my bookings all crammed onto one screen
  looked like "garbage." Also a reminder that drove the header rework: one
  person can be Admin, Audience, *and* Volunteer at the same time — the
  screen must never collapse that down to a single role.
- Searched for current (2026) mobile settings/profile UI guidance before
  redesigning (Android Settings design guidelines, Material 3 grouping
  patterns) — the actionable takeaways applied: group related items under
  one heading separated by dividers rather than scattering them as separate
  boxes; keep primary actions prominent and secondary ones subdued; use
  whitespace intentionally instead of stacking bordered containers.
- **Root cause of "looks unrelated"**: the screen mixed a solid white
  Material `Card` (Personal Details) with translucent dark glass cards
  (everything else) on the same dark gradient background — visually two
  different apps stitched together. Fixed by converting `_BookingDetailsCard`
  to the same dark-glass `GlassCard` + white-styled `TextFormField`s used
  everywhere else (`student_profile_screen.dart`).
- **Root cause of "garbage" layout**: Admin Account alone was *eight*
  separate floating boxes (a phone-number info card, four individually
  bordered stat tiles across two rows, four individually bordered action
  buttons) each with their own border/shadow/gap — no grouping at all.
  Consolidated into one `GlassCard` per section, using new shared widgets:
  - `_MiniStat` — compact number+label separated by hairline vertical
    dividers instead of each stat being its own bordered box.
  - `_SettingsRow` — a plain tappable row (icon + label + chevron, no
    individual border/background) for Change Password / Logout / Unsubscribe
    / Delete Account, so they read as one list, not four separate buttons.
  - `_CardDivider` — hairline divider used *within* a card to separate
    logical groups (e.g. neutral actions from destructive ones), never
    between two different cards.
  - `_ProfileSection` — one wrapper every section now goes through: a small
    caps label followed by exactly one card, nothing else. Replaces the old
    per-section `_SectionDivider` + loose children pattern.
- **Header rework for the "can be multiple roles" reminder**: replaced the
  single-badge `_AvatarHeader`/`_Role` enum with `_ProfileHeader` +
  `_RoleBadge`, which renders a `Wrap` of every applicable badge (Admin,
  Volunteer, Audience — any combination, "Member" only if none apply)
  instead of picking one. `_Role` enum, `_AvatarHeader`, `_SectionDivider`,
  `_InfoCard`, and the old `_ActionTile` were all deleted as obsolete once
  their call sites were replaced (`_InfoCard`'s content — subscribed number
  — moved inline into the new Admin card).
- My Bookings section (`_AudienceSection`) previously had no unifying card
  background of its own (individual pass tiles only) — now wrapped in a
  `GlassCard` at the call site for the same reason: every section is now
  exactly one card, never zero or many.
- `flutter analyze` clean throughout. Not yet visually verified on a device
  — this was the largest single-file rewrite this session, worth a careful
  look especially at: the multi-badge header with 1/2/3 badges present, the
  Admin card's 4-way `_MiniStat` row on a narrow phone, and that every
  destructive action (Unsubscribe, Delete Account) still triggers its
  confirmation dialog correctly (logic was preserved, not rewritten, but
  worth confirming after this much structural churn).

Sources consulted:
- [Android settings design guidelines](https://source.android.com/docs/core/settings/settings-guidelines)
- [Settings UI design: Why users can't find what they need](https://www.setproduct.com/blog/settings-ui-design)
- [Profile Page UI Design: Best Practices, Examples & How to Build One (2026)](https://www.uxpin.com/studio/blog/profile-page-ui-design/)

## 2026-07-21 session (continued — item 35)

### 35. SafeArea/overflow audit after item 34's redesign
- User asked to confirm SafeArea usage and MediaQuery-based responsiveness
  across devices after the item 34 visual pass.
- **SafeArea audit**: `for f in lib/features/**/*.dart; grep -L SafeArea`
  found 8 files without it. All but 2 use plain `Scaffold(appBar: AppBar(...),
  body: ...)`, which is already safe-area-correct by default (Scaffold pads
  the body relative to the AppBar/system chrome without needing an explicit
  `SafeArea` — only screens with a custom full-bleed header in place of an
  `AppBar` need one, e.g. the gradient screens, which already all had it:
  splash, subscribe/phone/OTP, login, join, volunteer join, profile). The
  other 2 (`scanner_screen.dart`, `volunteer_scanner_screen.dart`) wrap a
  `Scaffold` in an outer `Stack` for the green-flash overlay, but that
  overlay is `IgnorePointer`-only cosmetic, not interactive content sitting
  under system chrome — not a real gap. Conclusion: no missing SafeArea
  found beyond what was already correct.
- **Overflow audit**: found 3 genuine gaps — stat-value `Text`/`RichText`
  widgets with no overflow guard, all following the same pattern (bold
  numeric text, no `FittedBox`/`maxLines`), which could wrap or clip on
  narrow devices with large counts:
  - `venue_list_screen.dart`'s new `_DashStat` (item 34) — the
    `$totalBooked/$totalCapacity` value in particular can get long.
  - `student_profile_screen.dart`'s pre-existing `_StatTile`.
  - `venue_detail_screen.dart`'s pre-existing `_StatCard` (`RichText`).
  All three wrapped in `FittedBox(fit: BoxFit.scaleDown)` (`alignment:
  centerLeft` for the `RichText` one, to match its left-aligned column) plus
  `maxLines: 1` + ellipsis on the label under it.
- `flutter analyze` clean. Not yet tested on an actual narrow/small device —
  the fixes are defensive (guard against a failure mode that's plausible but
  not yet confirmed reproduced), not fixes for a reported live overflow
  error.

## 2026-07-21 session (continued — item 34, closes out item 6)

### 34. Visual redesign pass on the three role landing screens
- Follow-up to item 6 from the earlier punch list ("Admin, Audience and
  Volunteer screen make them awesome") — user confirmed to proceed directly
  rather than scoping further, so treated "Admin/Audience/Volunteer screen"
  as each role's primary screen reached from the splash role-picker.
- **Admin** (`venue_list_screen.dart`) — the worst offender: was a plain
  white `Scaffold`/`AppBar`/Material `Card` list, visually disconnected from
  the branded gradient look everywhere else in the app. Rewritten to use
  `authGradient` background, a custom header (matches join/volunteer screens'
  pattern), a new 3-up dashboard stat row (`_DashStat`: total venues,
  booked/capacity, checked-in — aggregated across all venues), glass-style
  `_VenueCard`s (replacing plain `Card`s) with staggered fade+slide-in per
  card, and a redesigned empty state using `AuthPrimaryButton`. Functionally
  identical (same taps go to the same routes) — pure visual layer change.
- **Audience** (`join_screen.dart`) — already used the gradient+glass look;
  the one remaining plain-white element was the "My Entry Passes" list
  (stock `ListTile`s inside a Material `Card`). Replaced with a `GlassCard`
  and new `_PassRow` widgets matching the venue-card visual language, with a
  fade-in.
- **Volunteer** (`volunteer_join_screen.dart`) — already close in shape to
  Audience's screen but used generic `kIndigo` for its icon/button despite
  being the "emerald" role everywhere else (splash role tile, per
  `splash_screen.dart`'s `_RoleTile` colors). Recolored the form icon and
  submit button to the same emerald (`0xFF10B981`), added a header icon
  badge (matching Audience's lock-icon badge pattern), and added the
  fade+slide-in entrance animation the card was missing.
- `flutter analyze` clean throughout. Not yet visually verified on a device
  — worth a look on all three screens, especially the new Admin dashboard
  stat row at narrow phone widths.
- **Deliberately not touched**: deeper screens in each flow (venue detail/
  create/scanner for Admin; seat map/booking/entry pass for Audience;
  status/scanner for Volunteer) — those already inherit branded styling in
  parts (venue_detail, entry_pass) or are functionally dense enough
  (seat-map grid interaction) that a visual pass risks touching working
  logic. If the user wants those "awesome" too, treat as a separate,
  scoped follow-up rather than assuming it was covered here.

## 2026-07-21 session (continued — item 33)

### 33. Profile icon restored on the role-picker screen; dead avatar removed from Admin
- Partial reversal of item 29 above, per explicit user follow-up: they want
  a profile entry point back on the splash/role-picker screen ("VenueLock"
  title, Admin/Audience/Volunteer cards) in addition to the post-login
  landing screen — `splash_screen.dart` top-right `IconButton` → push
  `/student/profile`, same as before item 29 removed it.
- Also removed the `CircleAvatar` in `venue_list_screen.dart`'s AppBar
  actions — it showed the admin's initial but had no `onTap`, i.e. was a
  non-functional "profile" the user rightly called out as unusable. Deleted
  outright rather than wired up, since Profile is already one tap away via
  the back arrow → role picker → profile icon, or directly reachable as the
  post-login landing screen (item 29).

## 2026-07-21 session (continued — items 28-32)

User gave a 7-item punch list after item 27. Items 1,2,3,5,7 fixed below;
item 4 verified working (no bug found); item 6 (visual polish of the three
role screens) deliberately not started — flagged back to the user for scope
since it's a large, subjective redesign, not a bug fix.

### 28. Misleading "Send OTP" button for already-subscribed returning users
- Follow-on from item 27: since the phone screen now silently skips OTP for
  numbers with an existing account, the button still saying "Send OTP" was
  actively wrong for that path. Changed button label to "Continue" and
  reworded the helper text above it to cover both outcomes ("Already
  subscribed? We'll take you straight to login. Otherwise, we'll send a
  6-digit OTP...") — `phone_screen.dart`.

### 29. Profile is now the one landing screen after login; other entry points removed
- User: "after log in the opening screen should have profile screen and no
  other screen should have profile screen." Previously login success went to
  `'/'` (role picker), and profile was also reachable from the Audience
  booking screen ("Edit Profile") and the Volunteer join/status screens (a
  profile icon added in the 2026-07-18 session, item 21) — three ways in,
  landing screen wasn't one of them.
- `router.dart`: both "already/just logged in" redirect targets changed from
  `'/'` to `'/student/profile'` (the subscribe-path-already-logged-in case
  and the login-path-already-logged-in case).
- `admin_login_screen.dart`: both `_LoginForm`/`_RegisterForm` `onSuccess`
  now `context.go('/student/profile')` instead of `context.go('/')`.
- Removed the other entry points: `booking_screen.dart`'s "Edit Profile"
  link, and the profile icons in `volunteer_join_screen.dart` and
  `volunteer_status_screen.dart` (the latter's whole header row, added
  solely to host that icon, reverted to no header — matches its pre-item-21
  layout).
- Since Profile is now often the navigation root (no route below it to pop
  to), its back arrow is now `context.canPop() ? context.pop() :
  context.push('/')` — falls back to the role picker instead of a no-op, so
  a logged-in admin can still reach Audience/Volunteer mode on the same
  device.
- Added a "Manage Venues" `FilledButton` at the top of the Admin section
  (`student_profile_screen.dart`, `_AdminSection`) since Venues is no longer
  reachable from anywhere else once Profile is the landing screen.

### 30. Admin's Attendees list auto-refreshed every 3s — made manual
- User: "in Admin screen - attendees keep refreshing automatically. make it
  manual." `venue_detail_screen.dart` used `AppState.seatsStream()`
  (`Timer.periodic` every 3s) via `StreamBuilder`. Converted the screen to a
  one-shot `getSeats()` fetch in `initState`, with a refresh icon button in
  the AppBar and pull-to-refresh (`RefreshIndicator`) as the only ways to
  update the list now.
- Deliberately scoped to just this screen — `seatsStream` itself is
  untouched and still used (correctly, left as live-polling) by
  `scanner_screen.dart` (needs live check-in feedback),
  `seat_reserve_screen.dart` (needs live seat availability while reserving),
  and `seat_map_screen.dart` (audience needs live seat availability while
  picking a seat).

### 31. Volunteer Applications review — checked, no bug found
- User asked to verify this works. Read both sides end to end:
  `volunteer_review_screen.dart` (list/approve/reject UI, busy-state per
  row, refresh-after-action) against `venuelock_volunteer_review.php` /
  `venuelock_volunteer_list.php` (venue-ownership-checked via
  `admin_phone`, session-authenticated, correct SQL). No bug found — approve/
  reject correctly update `volunteers.status` and the list re-fetches after
  each action.

### 32. "How does a volunteer apply? There's no code" — found the actual gap
- The volunteer apply flow itself was fine (`volunteer_join_screen.dart`
  already has a 6-char access-code field, identical in shape to the
  Audience join flow, posting to `venuelock_volunteer_apply.php`). The real
  gap: `venue_detail_screen.dart`'s Access Code card only said "Share this
  code with attendees" — never told the admin that the *same* code is what
  volunteers use to apply. From the admin's side, there was no visible way
  to know volunteers could join at all. Reworded to "Share this code with
  attendees to book a seat, or with volunteers to apply to scan entries
  here."

### Not yet done
- **Item 6 (visual polish)**: user said the Admin/Audience/Volunteer screens
  are "boring." Not started — this is a genuinely large, subjective design
  pass (similar scope to the abandoned `app_v2` rebuild), not a bug fix, so
  it needs direction from the user (which screens first, how much visual
  latitude) before starting rather than guessing.
- None of items 28/29/30/32 have been exercised on-device yet, only
  `flutter analyze` (clean throughout). Item 29 in particular changes the
  core post-login navigation shape — worth a full click-through: login →
  lands on profile → "Manage Venues" → back arrow behavior at each depth →
  hardware back parity (item 26/5's fix should now also apply cleanly given
  the new landing screen).

## 2026-07-21 session

### 27. Already-subscribed returning admins can skip OTP and go straight to password login — wired to server
- Follow-up to item 26. User clarified the actual want: a returning admin
  who's already subscribed shouldn't have to repeat the BdApps OTP
  round-trip at all — phone + password login should be enough — and asked
  to actually connect this to the server, not just patch client state.
- **Constraint discovered**: BdApps carrier billing has no "check
  subscription status" endpoint reachable without an OTP challenge — status
  can only be learned via the `send_otp.php` → `verify_otp.php` round-trip.
  So there's no way to silently confirm "still an active subscriber"
  server-side without OTP. What *is* available and previously unused:
  `ARIF(VL)/venuelock_check_phone.php` — checks whether a phone already has
  a row in the `users` table (a registered login account). Since account
  registration is only reachable after passing the subscribe+OTP gate once,
  an existing account is a reliable proxy for "already subscribed before."
- `core/services/subscription_service.dart`: added
  `checkExistingAccount(phone)` (calls `venuelock_check_phone.php`, returns
  `null` on network failure so callers fail open to the normal OTP flow
  rather than blocking) and `markSubscribedLocally(phone)` (same effect as
  completing OTP verification — persists the phone under the existing
  `venuelock_subscribed_phone` prefs key, sets `isSubscribed = true`).
- `features/admin/subscription/phone_screen.dart`: `_submit()` now calls
  `checkExistingAccount` first. If it returns `true`, calls
  `markSubscribedLocally` and routes straight to `/admin/login` — no OTP
  screen. Otherwise (new number, or check failed/timed out) falls through to
  the existing `sendOtp` → OTP screen flow unchanged.
- `flutter analyze` clean. Not yet verified live — needs a real phone number
  with an existing `users` row tested against the production backend to
  confirm `venuelock_check_phone.php` actually short-circuits to the login
  screen as intended.

### 25. `app_v2` deleted by user — `app/` is the only app again
- User deleted the `app_v2` rebuild from item 24 (2026-07-18 session) after
  trying it. No reason given. `app/` remains the one live codebase.

### 26. Post-logout stuck on the subscribe/phone/OTP screen instead of login — router hardened
- User reported: after logging out of an already-subscribed account, they
  couldn't log back in — landed on "Enter mobile number" with a "Send OTP"
  button (the Gate-1 subscribe/phone screen), not the Gate-2 login screen.
  Pointed at `C:\Local_Disk_D\App\MedRemind\med_remind_v2` and asked to
  follow that app's server/gating functionality.
- Read MedRemind's `app/AUTH_AND_SUBSCRIPTION.md` in full and cross-checked
  its actual `auth_service.dart`/`auth_provider.dart` source. Its two-gate
  architecture, accepted OTP-status set, and "logout only clears Gate 2 /
  unsubscribe clears both gates" behavior are **already identical** to
  VenueLock's (`app/lib/core/services/subscription_service.dart` +
  `auth_service.dart`) — logout there only calls `AuthService.logout()`,
  never touches `SubscriptionService`, so a real code-level "logout silently
  unsubscribes you" bug was ruled out by inspection.
- The one structural difference MedRemind's doc calls out as deliberate:
  their flow-gate is a **reactive state machine** (`main.dart` watches both
  auth providers on every `build()` and self-corrects if state and screen
  ever disagree, explicitly to "avoid a whole class of navigation bugs...
  wrong screen after async gaps"). VenueLock's `app/lib/app/router.dart`
  used go_router's declarative `redirect` callback **without**
  `refreshListenable`, meaning `redirect` only re-runs on an explicit
  navigation call — if `authService`/`subscriptionService` ever change state
  without a matching `context.go`/`push` right after (an async gap), the
  user could get stranded on a stale screen until some other navigation
  happens to fire.
- **Fix**: added `refreshListenable: Listenable.merge([authService,
  subscriptionService])` to the `GoRouter` in `router.dart` — now any state
  change on either service (not just explicit navigations) re-evaluates the
  `redirect` gate against the current location automatically, closing that
  class of staleness bug without restructuring to MedRemind's imperative
  state-machine pattern (go_router's own recommended way to get the same
  reactivity).
- `flutter analyze` clean.
- **Not fully root-caused**: I could not reproduce the exact "stuck at
  phone/OTP after logout" sequence from static code reading alone — the
  explicit `context.go('/admin/login')` call already present after logout
  (in `student_profile_screen.dart`'s Logout action) traces correctly to the
  login screen on paper. The `refreshListenable` fix closes the most
  plausible general mechanism (a stale/missed redirect re-evaluation) but if
  the user hits this again, get exact repro steps (which button was tapped:
  Logout vs Unsubscribe — they're adjacent destructive-styled tiles on the
  profile screen and easy to conflate — and whether it's after an explicit
  in-app logout or after killing/reopening the app).

## 2026-07-18 session

### 24. `app_v2` — full app rebuilt with the same features, new UI/UX/nav
- User had already run `flutter create` for a new `app_v2/` folder (sibling
  to `app/`) and asked for it to be built out with identical functionality
  but "awesome" UI, with explicit sign-off (via clarifying questions) to
  build it all in one pass and to rework navigation/UX, not just reskin.
- Delegated the actual build to a background general-purpose agent with a
  detailed brief covering: the full feature inventory (subscription gate,
  admin auth, venue management, audience booking, volunteer flow, the
  just-redesigned unified profile screen), the non-negotiable constraint to
  keep the live PHP backend contract (`ARIF(VL)/`, documented in
  `API_USAGE.md`) byte-identical — same endpoints/request shapes/storage
  keys — and explicit permission to redesign visuals and navigation
  structure.
- Verified independently after the agent reported done (its own tool-use
  count looked suspiciously low for the claimed scope, so didn't take the
  "0 issues" claim on faith): ran `flutter pub get` + `flutter analyze`
  myself in `app_v2/` — genuinely clean, 0 issues. Spot-checked file count
  (39 files vs v1's 33), `main.dart`/`router.dart` wiring, and that the icon
  assets were actually copied (`assets/icon/app_icon_v2.{png,svg}`,
  437KB — not a stub).
- What's structurally different from v1:
  - Routes reorganized under role-scoped prefixes: `/onboarding/*` (was
    `/admin/subscribe*`), `/auth/*` (was `/admin/login`,
    `/admin/forgot-password`), `/admin/*`, `/audience/*` (was `/student/*`),
    `/volunteer/*`, top-level `/profile` (was `/student/profile`).
  - New `features/admin/shell/admin_shell_screen.dart`: persistent
    bottom-nav shell (Venues / Profile tabs) for the admin area — v1 had no
    direct nav into profile from the admin venue list, this closes that gap.
    Other admin actions (create venue, scanner, reserve, volunteer review)
    stay as pushed screens on top of the shell.
  - New `lib/design/brand_surface.dart` consolidates widgets v1 had
    duplicated (e.g. the separate `_OtpBox` in both `otp_screen.dart` and
    `forgot_password_screen.dart`) into one shared implementation.
  - Two-gate router `redirect` logic (subscription gate, then login gate)
    ported verbatim in spirit, just against the renamed route paths.
- What's unchanged on purpose: `core/models/`, `core/services/` — copied
  with the same endpoints/request bodies/SharedPreferences keys as v1, since
  the backend and any already-installed v1 app's local storage must stay
  compatible. Palette-switching (indigo/emerald/rose/amber ×
  light/dark/system) kept as a feature, just restyled.
- `app/` (v1) was left completely untouched — still the reference/fallback.
- **Not yet done**: no screen has been visually run/eyeballed on a device or
  emulator yet — only `flutter analyze` (static) has been verified. Next
  session (or right now, if resuming) should `flutter run` app_v2 on the
  connected device and click through all three role flows before trusting
  it beyond "compiles."

## 2026-07-17 session

### 23. Profile sections un-gated — same fixed layout for every user
- User pushed back on item 21/22's design (Volunteer/Audience sections only
  rendering when that role's data existed): "user is one person - then one
  profile is enough to show all info," i.e. sections popping in/out based on
  activity read as separate role-profiles stitched together, not one profile.
- `student_profile_screen.dart`: `MY BOOKINGS` and `VOLUNTEER STATUS` are now
  always rendered in a fixed order (Personal Details → Admin Account →
  My Bookings → Volunteer Status → Appearance) for every user, admin or not.
  When there's no data for a section, it shows a small `_EmptyState` card
  ("No bookings yet — join a venue with its code to reserve a seat." /
  "Not volunteering anywhere yet — apply with a venue's access code.")
  instead of disappearing.
- Admin Account is the one exception, still gated on `auth.isLoggedIn` — it's
  a real authenticated account/session with actions (logout, change
  password, delete account) that are meaningless to show for someone who
  isn't signed in, unlike Volunteer/Audience which are just local
  device-stored activity with no login concept.
- Simplified `_Role` from four values (admin/volunteer/audience/guest) down
  to two (admin/member) since the avatar badge no longer needs to guess a
  "primary" role from whichever section happened to have data — every non-
  admin is just "Member" now.
- `flutter analyze` clean.

### 22. Audience profile sharpened for multiple venues
- User said "there are no profile for audience" and pointed out an audience
  member may have booked seats at multiple venues. The Audience section added
  in item 21 (2026-07-16) already existed and iterated all saved passes, but
  had no sense of *when* each event was — just a flat list of venue/seat
  pairs, no summary, no distinction between an event happening next week vs
  one that already passed.
- `app/lib/core/services/pass_storage.dart`: `SavedPass` gained an optional
  `eventDate` field (nullable, ISO-string persisted — old saved passes
  without it just deserialize with `eventDate: null`, no migration needed).
- `app/lib/features/student/booking/booking_screen.dart`: now passes
  `eventDate: _venue?.eventDate` when saving a pass after a successful
  booking.
- `app/lib/features/student/profile/student_profile_screen.dart`
  `_AudienceSection` rewritten:
  - Two stat tiles up top (reusing the same `_StatTile` admin already had):
    distinct venue count ("Venues Attending") and total booking count,
    singular/plural label handling.
  - Passes now split into **UPCOMING** / **PAST** groups (by comparing
    `eventDate` to today, passes without a date treated as upcoming so they
    don't silently vanish), upcoming sorted soonest-first, past sorted most-
    recent-first, past entries rendered visibly dimmed.
  - Each pass tile now shows the formatted event date next to the seat label
    instead of just "Seat X".
- `flutter analyze` clean. Not yet verified live — no device pass currently
  has `eventDate` populated until a new booking is made post-update, so the
  upcoming/past split and date text should be checked against a fresh
  booking, not an old saved pass.

## 2026-07-16 session

Repo is a single Flutter codebase (`app/`) built for both mobile and web — no
separate web frontend, so every fix below applies to both targets from one
source change.

### 21. Profile screen redesigned to be role-aware (Admin/Volunteer/Audience/Guest)
- User asked for Audience and Volunteer to have "their own" profile too, and
  for the shared profile screen to show correct info per role, in order, with
  a nicer UI. It was previously admin-only-aware: booking-details form
  always, plus an admin section bolted on top when signed in — Volunteer/
  Audience got no role-specific content at all, and no entry point into the
  screen existed from the volunteer flow.
- `app/lib/features/student/profile/student_profile_screen.dart` rewritten:
  - New fixed section order for everyone: avatar header (now carries a role
    badge chip — Admin/Volunteer/Audience/Guest, colored + icon) → Personal
    Details form (name/email/roll, unchanged data) → role-specific section →
    Appearance (theme picker, moved out of admin-only gating so every role
    can use it).
  - New `_VolunteerSection`: shown when `VolunteerService.getActiveApplication()`
    finds an active application — venue name, live status chip (pending/
    approved/rejected via `VolunteerService.getStatus`), "View Status" button
    pushing to the existing `/volunteer/status/:venueId/:volunteerId` screen
    (reuses its polling/auto-redirect-to-scanner logic, not duplicated here).
  - New `_AudienceSection`: shown when `PassStorage.getPasses()` has saved
    passes — lists each booked venue/seat, tapping one pushes to
    `/student/pass/:venueId/:seatId`.
  - `_AdminSection` unchanged in content, just no longer renders its own
    avatar header or appearance card (both hoisted to the shared top level).
  - Sections are additive, not exclusive on role: e.g. a device that has both
    volunteered somewhere and booked a seat elsewhere shows both blocks.
- Added a profile icon entry point to `volunteer_join_screen.dart` (top-right,
  next to the back arrow) and to `volunteer_status_screen.dart` (previously
  had no header row at all) — Volunteer had no way to reach profile before
  this session except by backing out to the role picker.
- `flutter analyze` clean.
- Not yet verified live: role badge rendering, volunteer/audience section
  data loading (both are async in `initState` via `_loadExtras`), and that
  the new volunteer profile icons don't collide with existing back-button
  layout on a small screen.

### 20. Android/gesture back button exiting the app instead of navigating back — fixed
- **Symptom**: pressing the phone's back button from inside the app (e.g.
  after picking Admin/Audience/Volunteer from the role picker) closed the app
  entirely instead of going back a screen.
- **Root cause**: `SplashScreen`'s three role tiles
  (`app/lib/features/splash/splash_screen.dart`) called `context.go(...)` for
  role selection. `go_router`'s `go()` *replaces* the whole navigation stack
  rather than pushing onto it, so the moment a role was picked, `'/'` (the
  role picker) was discarded from history — there was nothing left on the
  Navigator stack to pop to, so the system back button fell through and
  exited the app.
- **Fix**: changed all three role-tile `onTap` handlers to `context.push(...)`
  instead of `context.go(...)`, so `'/'` stays on the stack underneath. The
  top-level `redirect` callback in `router.dart` (subscription/login gating)
  still applies identically under `push`, since go_router evaluates it
  per-navigation regardless of push vs go.
- Not yet re-verified on-device; `flutter analyze` is clean.

### 19. Redundant profile icon on the role-picker screen — removed
- User was confused why a profile icon appeared on the splash/role-picker
  screen (before even choosing a role) leading to the same
  `StudentProfileScreen`, describing it as "profile comes 2 times — Venue
  Lock screen and Admin screen." There was never a separate admin profile
  screen (confirmed no `/admin/profile` route or admin-side profile nav
  exists) — the actual issue was this stray top-right icon on
  `SplashScreen` (`app/lib/features/splash/splash_screen.dart`), irrelevant
  before role selection and definitely irrelevant to the Admin role.
- **Fix**: removed the `IconButton`/`Align` block from `SplashScreen`. The
  only remaining entry point into profile was (at the time) the "Edit
  Profile" button on the Audience booking screen — since superseded by item
  21 above, which added proper entry points for every role.

### 18. OTP digits clipped/not fully visible — fixed
- **Symptom**: on the OTP entry screen, typed digits looked cut off inside
  their boxes.
- **Root cause**: `_OtpBox` in
  `app/lib/features/admin/subscription/otp_screen.dart` sizes each digit box
  at a fixed 42×54px, but its `TextField`'s `InputDecoration` set no
  `contentPadding`/`isDense`/`isCollapsed`, so Material's default vertical
  content padding combined with the 22px digit glyph pushed text outside the
  fixed-height box (worst on web/Chrome where font metrics differ slightly
  from mobile Skia rendering).
- **Fix**: added `isCollapsed: true` and
  `contentPadding: EdgeInsets.symmetric(vertical: 16)` to that
  `InputDecoration` so the digit centers and renders fully inside the box.
  (Note: `forgot_password_screen.dart` has a duplicate `_OtpBox` widget per
  item 1's old fix note — not touched this session, may want the same fix if
  the same clipping is reported there.)

### 17. Phone number asked again at login/registration after subscription — mitigated
- User asked why they had to type a phone number again at login/registration
  when they'd already given it during the bdapps subscription gate. Confirmed
  via `app/AUTH_AND_SUBSCRIPTION.md` this is **by design**: subscription
  phone (carrier-billing gate, `SubscriptionService`) and login/registration
  phone (`AuthService`, a separate account system) are two intentionally
  decoupled backends — not a bug, not deduplicated data.
- **Fix (UX mitigation, not a backend merge)**: `admin_login_screen.dart`'s
  `_LoginForm` and `_RegisterForm` now pre-fill their phone field from
  `SubscriptionService.phone` in `initState` if it's already known, so
  returning users see it pre-populated instead of blank — still editable in
  case the login account uses a different number.

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
