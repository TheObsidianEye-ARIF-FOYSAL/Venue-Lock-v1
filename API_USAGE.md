# API Usage Map

Every network call the Flutter app makes, and the `ARIF(VL)/*.php` endpoint it
hits. Base URL defaults to `https://ruetandroiddevelopers.com/ARIF(VL)`
(see the `_kDefaultBaseUrl` / `_baseUrl` constant in each service below).

## `app/lib/core/services/auth_service.dart` — admin auth

| App call | Endpoint |
|---|---|
| `getProfile()` | `venuelock_profile.php` |
| `register()` | `venuelock_register.php` |
| `login()` | `venuelock_login.php` |
| `deleteAccount()` | `venuelock_delete_account.php` |
| `changePassword()` | `venuelock_change_password.php` |
| `sendOtp()` | `send_otp.php` |
| `verifyOtp()` | `verify_otp.php` |
| `resetPassword()` | `venuelock_reset_password.php` |

## `app/lib/core/services/subscription_service.dart` — admin subscription

| App call | Endpoint |
|---|---|
| `sendOtp()` | `send_otp.php` (shared with auth) |
| `verifyOtp()` | `verify_otp.php` (shared with auth) |
| `unsubscribe()` | `unsubscribe.php` |

## `app/lib/core/services/venue_service.dart` — venues, seats, booking

| App call | Endpoint |
|---|---|
| `getVenues()` | `venuelock_venue_list.php` |
| `getVenueByCode()` | `venuelock_venue_by_code.php` |
| `getVenueById()` | `venuelock_venue_get.php` |
| `createVenue()` | `venuelock_venue_create.php` |
| `getSeats()` | `venuelock_seats_list.php` |
| `bookSeat()` | `venuelock_seat_book.php` |
| `checkIn()` | `venuelock_checkin.php` |
| `reserveSeat()` / `releaseSeat()` | `venuelock_seat_reserve.php` |

## `app/lib/core/services/volunteer_service.dart` — volunteer role

| App call | Endpoint |
|---|---|
| `apply()` | `venuelock_volunteer_apply.php` |
| `pollStatus()` | `venuelock_volunteer_status.php` |
| `list()` (admin) | `venuelock_volunteer_list.php` |
| `review()` (admin approve/reject) | `venuelock_volunteer_review.php` |
| `checkIn()` (volunteer, device-token scoped) | `venuelock_volunteer_checkin.php` |

## Backend-only / not called directly by the app

These live in `ARIF(VL)/` but aren't hit directly by any Flutter service —
either internal helpers, carrier-billing SDK plumbing, or endpoints only
used by an external admin tool:

- `venuelock_db.php` — shared PDO/SQLite connection + session/CORS helpers
- `bdapps_cass_sdk.php`, `SMSReceiver.php`, `SMSSender.php`,
  `SMSServiceException.php`, `UssdReceiver.php`, `UssdSender.php`,
  `UssdException.php` — BDApps carrier SMS/USSD SDK used internally by
  `send_otp.php`/`verify_otp.php`, not called directly
- `subscriptionNotification.php` — BDApps subscription webhook (server-side
  callback, not app-initiated)
- `venuelock_check_phone.php` — no caller found in the current app code
  (dead/unused as of this writing)
