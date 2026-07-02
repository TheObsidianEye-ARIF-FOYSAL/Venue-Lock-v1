# VenueLock — Build Specification

**Tagline:** Lock the headcount. Unlock smooth entry.

A Flutter + Firebase app that lets an admin cap attendance at an exact number of seats, let students self-book a seat via a code or link, and verify everyone at the door with a single QR scan.

> **How to use this file:** This is written to be handed directly to an AI coding agent (Claude Code, etc.) as the project brief, or followed manually step by step. Each section is self-contained and ordered in the sequence you should build it.

---

## 1. Core concept & vocabulary

| Term in this app | What it means |
|---|---|
| **Venue** | An admin's event — has a name, date, total seat count, and a seat map |
| **Seat map** | The grid layout of seats for a Venue (rows × columns, with optional disabled cells for aisles) |
| **Access code** | 6-character code students type in to join a Venue |
| **Access link** | Optional shareable URL that opens the join screen directly |
| **Entry pass** | The QR code issued to a student after booking a seat |
| **Check-in** | The act of an admin scanning an Entry pass at the door |

---

## 2. Tech stack

- **Flutter** (stable channel) + **Dart 3.x**
- **Firebase**: Firestore (database), Firebase Auth (anonymous for students, email/Google for admins), Cloud Functions (atomic booking + check-in logic), Firebase Hosting (optional web fallback page for the access link)
- **State management: Riverpod** (with `@riverpod` code generation) — this is the current community default for new Flutter projects: compile-time safety, no `BuildContext` dependency, first-class async handling via `AsyncValue`, and far less boilerplate than Bloc for a project this size. Reach for Bloc only if you later bring on a large team that wants strict event-driven audit trails — not needed here.
- **Routing**: `go_router`
- **QR generation**: `qr_flutter`
- **QR scanning**: `mobile_scanner` — actively maintained, uses CameraX/ML Kit on Android and AVFoundation/Apple Vision on iOS, supports macOS and web too. (Avoid `qr_code_scanner` — it's unmaintained; its successor fork explicitly says "use mobile_scanner for new projects.")
- **Local offline cache for door-scanning**: `hive` or `isar`
- **Deep link for the access link**: `app_links` (do **not** use Firebase Dynamic Links — Google fully shut that service down in August 2025; all `page.link` URLs now 404)
- **Micro-animations**: `flutter_animate`, `lottie` (for the scan success/fail moment)

---

## 3. Project structure

```
lib/
  app/
    router.dart
    theme.dart
  core/
    services/
      firestore_service.dart
      auth_service.dart
    models/
      venue.dart
      seat.dart
      booking.dart
  features/
    admin/
      create_venue/
      seat_layout_editor/
      venue_dashboard/
      scanner/
      attendee_list/
    student/
      join_venue/
      seat_map/
      booking_form/
      entry_pass/
  shared_widgets/
    seat_grid.dart
    countdown_badge.dart
    empty_state.dart
main.dart
```

---

## 4. Bootstrap commands

Run these in order from an empty folder:

```bash
flutter create venuelock --org com.yourname --platforms android,ios
cd venuelock

# Firebase
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure   # select/create your Firebase project, registers Android + iOS apps

# Core packages
flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions
flutter pub add flutter_riverpod riverpod_annotation
flutter pub add go_router
flutter pub add qr_flutter mobile_scanner
flutter pub add hive hive_flutter
flutter pub add app_links
flutter pub add flutter_animate lottie
flutter pub add uuid

# Dev/codegen packages
flutter pub add -d build_runner riverpod_generator freezed freezed_annotation json_serializable
```

Initialize Firestore and deploy security rules + functions later with:
```bash
firebase init firestore functions
firebase deploy --only firestore:rules,functions
```

---

## 5. Firestore data model

```
venues/{venueId}
  name: string
  adminId: string
  totalSeats: number
  rows: number
  cols: number
  disabledSeats: string[]        // e.g. ["R3C5", "R3C6"] for aisles
  accessCode: string             // 6-char, unique
  status: "draft" | "open" | "locked" | "completed"
  eventDate: timestamp
  checkedInCount: number         // denormalized counter, updated by Cloud Function
  bookedCount: number            // denormalized counter, updated by Cloud Function

venues/{venueId}/seats/{seatId}      // seatId e.g. "R3C5" — one doc per seat
  row: number
  col: number
  status: "available" | "booked"
  bookedBy: string | null        // student uid
  studentName: string | null
  studentEmail: string | null
  qrToken: string | null         // random uuid, NOT the seat id — this is what's encoded in the QR
  checkedIn: boolean
  checkedInAt: timestamp | null
  bookedAt: timestamp | null
```

Why a subcollection of individual seat docs instead of one array field on the venue doc: an array field forces you to read and rewrite all 500 seats on every single booking, which causes write conflicts under load. Individual docs let Firestore transactions lock just the one seat being booked.

---

## 6. The two things that must run inside Cloud Functions, not the client

Never trust the client to do these two writes directly — a modified APK could fake a check-in or grab a seat without going through the queue.

### `bookSeat` (callable function)
```ts
export const bookSeat = onCall(async (request) => {
  const { venueId, seatId, studentName, studentEmail } = request.data;
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required");

  const seatRef = db.doc(`venues/${venueId}/seats/${seatId}`);
  const venueRef = db.doc(`venues/${venueId}`);

  return db.runTransaction(async (tx) => {
    const seatSnap = await tx.get(seatRef);
    if (!seatSnap.exists) throw new HttpsError("not-found", "Seat does not exist");
    if (seatSnap.data()!.status !== "available") {
      throw new HttpsError("already-exists", "Seat already booked");
    }

    // Optional: enforce one booking per student per venue by checking
    // a venues/{venueId}/bookings/{uid} doc here in the same transaction.

    const qrToken = crypto.randomUUID();
    tx.update(seatRef, {
      status: "booked",
      bookedBy: uid,
      studentName,
      studentEmail,
      qrToken,
      bookedAt: FieldValue.serverTimestamp(),
    });
    tx.update(venueRef, { bookedCount: FieldValue.increment(1) });

    return { qrToken, seatId };
  });
});
```

### `checkInStudent` (callable function, called from the admin's scanner)
```ts
export const checkInStudent = onCall(async (request) => {
  const { venueId, qrToken } = request.data;
  // TODO: verify request.auth belongs to the venue's admin

  const seatsRef = db.collection(`venues/${venueId}/seats`);
  const match = await seatsRef.where("qrToken", "==", qrToken).limit(1).get();
  if (match.empty) throw new HttpsError("not-found", "Invalid pass");

  const seatDoc = match.docs[0];
  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(seatDoc.ref);
    if (fresh.data()!.checkedIn) {
      throw new HttpsError("already-exists", "Already checked in");
    }
    tx.update(seatDoc.ref, { checkedIn: true, checkedInAt: FieldValue.serverTimestamp() });
    tx.update(db.doc(`venues/${venueId}`), { checkedInCount: FieldValue.increment(1) });
    return { studentName: fresh.data()!.studentName, seatId: seatDoc.id };
  });
});
```

The `qrToken` is a random UUID, never the seat number — so a screenshot can't be guessed or reused once `checkedIn` flips to `true`.

---

## 7. Firestore security rules (starting point)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /venues/{venueId} {
      allow read: if true; // needed so students can read venue info via the access code
      allow write: if request.auth.uid == resource.data.adminId;

      match /seats/{seatId} {
        allow read: if true;
        // all writes happen through Cloud Functions only — lock the client out entirely
        allow write: if false;
      }
    }
  }
}
```

Locking seat writes to `false` and forcing everything through `bookSeat`/`checkInStudent` is what makes the double-booking and duplicate-scan protection actually enforceable — a transaction in client code can still race against another client's transaction; a transaction inside one Cloud Function call cannot.

---

## 8. Screens

**Admin side**
1. **Admin login** — email/password or Google sign-in
2. **Venue list (dashboard)** — cards showing name, date, `bookedCount/totalSeats`, status chip
3. **Create venue wizard** — step 1: name + date; step 2: seat count + rows/cols; step 3: review & publish
4. **Seat layout editor** — tap-to-toggle grid to mark aisle/disabled cells before publishing
5. **Venue detail** — live `bookedCount` / `checkedInCount` counters, access code in large copyable text, share-link button, "Open scanner" button, attendee list, CSV export
6. **Scanner screen** — full-screen camera with a scan-window overlay, big running counter ("412 / 500 checked in"), green flash + haptic + chime on success, red flash + "already checked in" or "invalid pass" message on failure

**Student side**
1. **Join screen** — large code-entry field (auto-fills if opened via link), "Join venue" button
2. **Live seat map** — real-time grid (Firestore stream), available seats in one color, booked seats grayed out, tap to select, confirm button
3. **Booking form** — name, email, roll number (configurable per venue)
4. **Entry pass screen** — the payoff screen: QR code front and center, seat number, venue name/date, a boarding-pass-style card (rounded corners, a perforated divider line, subtle drop shadow), share/save-to-photos button

---

## 9. Making the UI feel premium, not generic

- **Theme**: `ThemeData(useMaterial3: true)` with a custom seed color via `ColorScheme.fromSeed`. Suggested seed: a deep indigo (locked/secure feeling) with a vivid green accent reserved only for "available seat" and "checked in" success states, and amber/red reserved for "pending" and "denied/full." Don't scatter color everywhere — let it carry meaning.
- **Seat grid**: animate seat selection with a subtle scale + color transition (`flutter_animate`'s `.scale()` + `.then().shimmer()` on the confirm), not an instant color swap.
- **Entry pass card**: model it visually like a boarding pass or concert ticket — a card with a dashed/perforated horizontal divider between the QR section and the seat-info section, rounded outer corners, soft shadow. This is the screen students will screenshot and show their friends, so it's worth the extra design pass.
- **Scanner feedback**: use `lottie` for a quick checkmark-burst animation on a valid scan and a shake/cross animation on an invalid one, paired with `HapticFeedback.mediumImpact()` — at a door with 500 people moving through, the admin needs feedback they can register at a glance without reading text.
- **Dark mode**: support it from day one via `ColorScheme.fromSeed(brightness: Brightness.dark)` — auditoriums are often dim, and the admin will likely be using the scanner screen in low light.
- **Empty/loading states**: skeleton placeholders for the seat grid while the first Firestore snapshot loads, rather than a bare spinner.

---

## 10. Handling the door-scanning offline risk

500 phones in one auditorium can strain wifi. Don't make every scan a live round-trip:

1. When the admin opens the scanner screen, pull the full `qrToken → seatId/studentName/checkedIn` list for that venue into a local Hive cache.
2. Validate each scan against the local cache instantly (no network wait).
3. Queue the `checkInStudent` call in the background; retry with backoff if it fails.
4. Reconcile the local cache against Firestore again once back online, in case two scanner devices were used.

---

## 11. Build order

- [ ] Firebase project setup + `flutterfire configure`
- [ ] Auth: anonymous sign-in for students, email/Google for admin
- [ ] Data models (`Venue`, `Seat`, `Booking`) with `freezed`
- [ ] Create-venue flow → generates seat subcollection on publish
- [ ] Student join-by-code → live seat map stream
- [ ] `bookSeat` Cloud Function + booking form + entry pass screen with `qr_flutter`
- [ ] Admin venue detail screen with live counters
- [ ] Scanner screen with `mobile_scanner` + `checkInStudent` Cloud Function
- [ ] Offline cache for scanning (Hive)
- [ ] Seat layout editor (aisle/disabled cells)
- [ ] CSV export of attendees
- [ ] Polish pass: animations, dark mode, empty states

## 12. Backlog (after MVP works end-to-end)

- Waitlist when a venue is full
- Auto-release a seat if not checked in within X minutes of event start
- Re-issue an entry pass if a student loses their device
- Multiple scanner devices checking in at once (already handled by the transaction in `checkInStudent`, just needs a UI note)
- Per-venue custom fields on the booking form (e.g. department, year)
