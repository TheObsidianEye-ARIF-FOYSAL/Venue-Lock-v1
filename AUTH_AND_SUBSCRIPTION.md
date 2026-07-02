# Auth & Subscription Architecture — Replication Guide

This document explains, in full implementation detail, how **MedRemind** (a Flutter app) implements:

1. A **paid mobile-operator subscription gate** ("BdApps" — Robi/Airtel direct-carrier-billing) that must be active before a user can use the app at all.
2. **Firebase Authentication** (email/password + Google Sign-In) for the actual user account, layered *on top of* the subscription gate.
3. The **app-flow state machine** that decides which screen to show on every launch based on the combination of subscription status, Firebase login status, and onboarding status.

It is written so that another engineer (or AI agent) can reproduce the exact same architecture in a different Flutter app, even without access to this codebase. Every code block below is either verbatim from the source or a minimal adaptation with comments explaining what to change.

---

## 1. Mental model

There are **two independent, stacked gates**, checked in this order on every app start:

```
                 ┌─────────────────────────┐
                 │ 1. BdApps subscription?  │──No──▶ SubscriptionScreen → PhoneScreen → OtpScreen
                 └─────────────────────────┘
                             │ Yes
                             ▼
                 ┌─────────────────────────┐
                 │ 2. Firebase logged in?   │──No──▶ LoginRegisterScreen (Login / Register tabs)
                 └─────────────────────────┘
                             │ Yes
                             ▼
                 ┌─────────────────────────┐
                 │ 3. Onboarding done?      │──No──▶ OnboardingIntroScreen → PermissionOnboardingScreen
                 └─────────────────────────┘
                             │ Yes
                             ▼
                        Main app (router)
```

- **Gate 1 (BdApps subscription)** is a *carrier billing* subscription — the user pays a small daily fee (e.g. ৳2.78/day) through their mobile operator (Robi or Airtel in Bangladesh), verified via **SMS OTP**, not through Google Play Billing or Apple IAP. This is common for apps distributed through the "BdApps" app store in Bangladesh, which requires operator-billed subscriptions.
- **Gate 2 (Firebase)** is a normal user account system, independent of the subscription. A user can log out of Firebase without losing their subscription (the subscription is tied to their *phone number*, stored locally, not to their Firebase account).
- **Gate 3 (onboarding)** is just first-run UX (intro slides + OS permission requests) — not really an "auth" concern, but it's part of the same flow gate so it's mentioned for completeness.

**Key design decision:** the subscription state and the Firebase auth state are **completely decoupled backends** — one is a custom PHP/HTTP API tied to a phone number, the other is Firebase. They're just both checked in sequence by the same top-level widget. This means:
- Unsubscribing does **not** delete the Firebase account.
- Logging out of Firebase does **not** cancel the subscription.
- Deleting the Firebase account **should** also cancel the subscription (see §5.5).

If your target app doesn't need real carrier billing, you can adapt Gate 1 into any kind of "entitlement check" (App Store/Play Store subscription receipt validation, a license key, a trial-expiry check, etc.) — the *shape* of the code (a `StateNotifierProvider<AuthNotifier, AuthState>` with `isAuthenticated`, checked first in the flow) stays the same; only the HTTP calls inside `AuthService` change.

---

## 2. Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management — both auth gates are Riverpod StateNotifiers
  flutter_riverpod: ^2.5.1

  # Session persistence (stores the subscribed phone number locally)
  shared_preferences: ^2.3.3

  # HTTP client for the custom subscription/OTP backend
  http: ^1.2.2

  # Firebase
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  google_sign_in: ^6.2.1
```

Run `flutter pub get` after adding these.

---

## 3. Firebase project setup (one-time, outside the code)

1. Create a Firebase project at https://console.firebase.google.com.
2. Add an Android app (and/or iOS app) with your package name / bundle ID.
3. Download `google-services.json` → place at `android/app/google-services.json`.
   - For iOS: download `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist`.
4. In `android/settings.gradle.kts` (this is where modern Flutter/AGP projects declare plugin versions — not the old `android/build.gradle.kts`), add the Google services plugin next to the existing `dev.flutter.flutter-plugin-loader`/`com.android.application`/Kotlin plugin declarations:
   ```kotlin
   plugins {
       id("dev.flutter.flutter-plugin-loader") version "1.0.0"
       id("com.android.application") version "9.0.1" apply false
       id("com.google.gms.google-services") version "4.4.4" apply false
       id("org.jetbrains.kotlin.android") version "2.3.20" apply false
   }
   ```
   (Versions above are exactly what this repo uses — pin to whatever your Flutter/AGP version actually requires if different.)
5. In `android/app/build.gradle.kts` (app-level), apply it:
   ```kotlin
   plugins {
       id("com.android.application")
       id("com.google.gms.google-services")
       id("dev.flutter.flutter-gradle-plugin")
   }
   ```
   The full app-level `build.gradle.kts` from this repo, for reference:
   ```kotlin
   android {
       namespace = "com.example.med_remind_v2"
       compileSdk = flutter.compileSdkVersion
       ndkVersion = flutter.ndkVersion

       compileOptions {
           sourceCompatibility = JavaVersion.VERSION_17
           targetCompatibility = JavaVersion.VERSION_17
           isCoreLibraryDesugaringEnabled = true
       }

       defaultConfig {
           applicationId = "com.example.med_remind_v2"
           minSdk = flutter.minSdkVersion
           targetSdk = flutter.targetSdkVersion
           versionCode = flutter.versionCode
           versionName = flutter.versionName
       }

       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("debug")
           }
       }
   }

   kotlin {
       compilerOptions {
           jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
       }
   }

   dependencies {
       coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
   }

   flutter {
       source = "../.."
   }
   ```
6. **No native code is needed for either gate.** `android/app/src/main/kotlin/.../MainActivity.kt` is a bare stub — nothing auth/subscription-related happens natively; everything (including `Firebase.initializeApp()`) runs in Dart:
   ```kotlin
   package com.example.med_remind_v2

   import io.flutter.embedding.android.FlutterActivity

   class MainActivity : FlutterActivity()
   ```
7. In Firebase Console → Authentication → Sign-in method, enable:
   - **Email/Password**
   - **Google**
8. For Google Sign-In specifically, you need the **Web client ID** (OAuth client with `client_type: 3`) from `google-services.json` — copy the `client_id` value into the Dart code (see §5.1, `serverClientId`). This is required on Android even though you're not building a web app; it's how `google_sign_in` gets an `idToken` that Firebase can verify server-side.
9. Run `flutterfire configure` (from the FlutterFire CLI) to auto-generate `lib/firebase_options.dart`, or hand-write it. `main.dart` calls `Firebase.initializeApp()` with no explicit options because `firebase_options.dart` is wired in automatically by `flutterfire configure` — if you hand-roll this, pass `options: DefaultFirebaseOptions.currentPlatform` explicitly.

---

## 4. Gate 1 — BdApps / carrier-billing subscription

### 4.1 Backend contract

This app talks to a **custom PHP backend** (not a Firebase/Google product) at a base URL configured via a compile-time define:

```dart
const _kDefaultBaseUrl = String.fromEnvironment(
  'SERVER_BASE_URL',
  defaultValue: 'https://ruetandroiddevelopers.com/ARIF(MR)',
);
```

Built with: `flutter run --dart-define=SERVER_BASE_URL=https://your-server.com/path`

Three endpoints, all under that base URL:

| Endpoint | Method | Purpose |
|---|---|---|
| `/send_otp.php` | POST (form-urlencoded) | Request an OTP SMS to a phone number |
| `/verify_otp.php` | POST (form-urlencoded) | Verify the OTP code and get subscription status |
| `/unsubscribe.php` | POST (JSON) | Cancel an active subscription |

**`send_otp.php`** request body: `{'user_mobile': '01812345678'}` (11-digit local format, no country code).
Expected JSON response: `{"referenceNo": "..."}`  — this reference number must be echoed back on verify. On failure: `{"statusCode": "...", "statusDetail": "..."}`.

**`verify_otp.php`** request body: `{'Otp': '123456', 'referenceNo': '<from send_otp>'}`.
Expected JSON response includes a `subscriptionStatus` (or `subscription_status`) field. The app treats these values as "successfully subscribed":
```
REGISTERED, SUBSCRIBED, ACTIVE, S1000,
INITIAL CHARGING PENDING, PENDING INITIAL CHARGING
```
(comparison is done uppercased with underscores replaced by spaces). A `statusCode` of `S1000` is also accepted as success even if `subscriptionStatus` isn't one of the above.

**`unsubscribe.php`** request body (JSON): `{"subscriberId": "8801812345678"}` — note this endpoint wants the **full international format with country code (880)**, unlike the other two endpoints which want the local 11-digit format. The conversion logic:
```dart
final subscriberId = normalized.startsWith('0')
    ? '88$normalized'                                            // 01812345678 → 8801812345678
    : (normalized.length == 10 && normalized.startsWith('1')
        ? '880$normalized'                                        // 1812345678  → 8801812345678
        : normalized);
```
Expected JSON response: success is `statusCode == 'S1000'` or `subscriptionStatus == 'UNREGISTERED'`.

### 4.2 `AuthService` (raw HTTP layer)

Full file — `lib/features/auth/services/auth_service.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const _kDefaultBaseUrl = String.fromEnvironment(
  'SERVER_BASE_URL',
  defaultValue: 'https://ruetandroiddevelopers.com/ARIF(MR)',
);

class AuthService {
  final Map<String, String> _referenceByPhone = {};
  final String _baseUrl;

  AuthService({String? baseUrl})
      : _baseUrl = _sanitize(baseUrl ?? _kDefaultBaseUrl);

  Future<void> sendOtp(String phone) async {
    final normalized = _normalize(phone);
    final response = await http
        .post(
          Uri.parse('$_baseUrl/send_otp.php'),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: {'user_mobile': normalized},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('OTP request failed (${response.statusCode})');
    }

    final map = _json(response.body);
    final ref =
        (map['referenceNo'] ?? map['reference_no'] ?? '').toString().trim();
    if (ref.isNotEmpty) {
      _referenceByPhone[normalized] = ref;
      return;
    }

    final code = (map['statusCode'] ?? 'UNKNOWN').toString();
    final detail =
        (map['statusDetail'] ?? 'Unable to request OTP').toString();
    throw Exception('$detail ($code)');
  }

  Future<bool> verifyOtp(String phone, String code) async {
    final normalized = _normalize(phone);
    final ref = _referenceByPhone[normalized];
    if (ref == null || ref.isEmpty) {
      throw Exception('No OTP request found. Please request OTP again.');
    }

    final response = await http
        .post(
          Uri.parse('$_baseUrl/verify_otp.php'),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: {'Otp': code, 'referenceNo': ref},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('OTP verification failed (${response.statusCode})');
    }

    final map = _json(response.body);
    final status = _upperTrim(
        map['subscriptionStatus'] ?? map['subscription_status'] ?? '');
    final accepted = {
      'REGISTERED', 'SUBSCRIBED', 'ACTIVE', 'S1000',
      'INITIAL CHARGING PENDING', 'PENDING INITIAL CHARGING'
    };
    if (accepted.contains(status)) {
      _referenceByPhone.remove(normalized);
      return true;
    }
    if (_upperTrim(map['statusCode'] ?? '') == 'S1000') {
      _referenceByPhone.remove(normalized);
      return true;
    }
    return false;
  }

  Future<bool> unsubscribe(String phone) async {
    final normalized = _normalize(phone);
    final subscriberId = normalized.startsWith('0')
        ? '88$normalized'
        : (normalized.length == 10 && normalized.startsWith('1')
            ? '880$normalized'
            : normalized);

    final response = await http
        .post(
          Uri.parse('$_baseUrl/unsubscribe.php'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'subscriberId': subscriberId}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Unsubscribe failed (${response.statusCode})');
    }

    final map = _json(response.body);
    final code =
        _upperTrim(map['statusCode'] ?? map['status_code'] ?? '');
    final subStatus = _upperTrim(
        map['subscriptionStatus'] ?? map['subscription_status'] ?? '');

    if (code == 'S1000' || subStatus == 'UNREGISTERED') {
      _referenceByPhone.remove(normalized);
      return true;
    }

    final detail =
        (map['statusDetail'] ?? map['status_detail'] ?? 'Unsubscribe failed')
            .toString()
            .trim();
    throw Exception(detail.isEmpty ? 'Unsubscribe failed' : detail);
  }

  Map<String, dynamic> _json(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) return data;
      throw const FormatException();
    } catch (_) {
      throw Exception('Invalid server response');
    }
  }

  String _normalize(String phone) {
    final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('880') && d.length > 10) return d.substring(3);
    if (d.startsWith('88') && d.length > 11) return d.substring(2);
    return d;
  }

  String _upperTrim(dynamic v) =>
      v.toString().toUpperCase().replaceAll('_', ' ').trim();

  static String _sanitize(String raw) {
    final t = raw.trim();
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }
}
```

**Adapting this for a different backend/store:** replace the three HTTP methods with whatever your entitlement check needs (e.g. `in_app_purchase` receipt validation, a license-key POST, a Stripe subscription check). Keep the same method *signatures* (`sendOtp`/`verifyOtp`/`unsubscribe` → rename freely) so the provider layer below doesn't need to change.

### 4.3 `AuthNotifier` / `authProvider` (state layer)

Full file — `lib/features/auth/providers/auth_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class AuthState {
  final bool isAuthenticated;
  final String? phone;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.phone,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? phone,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        phone: phone ?? this.phone,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState()) {
    _loadSession();
  }

  // On app start, check SharedPreferences for a previously-verified phone
  // number. If present, the user is considered subscribed — no network
  // call needed on every launch, only on explicit subscribe/unsubscribe.
  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('bdapps_phone');
    if (phone != null) {
      state = state.copyWith(isAuthenticated: true, phone: phone);
    }
  }

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.sendOtp(phone);
      state = state.copyWith(isLoading: false, phone: phone);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final ok = await _service.verifyOtp(state.phone!, code);
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bdapps_phone', state.phone!);
        state = state.copyWith(isLoading: false, isAuthenticated: true);
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Invalid OTP');
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<bool> unsubscribe() async {
    state = state.copyWith(isLoading: true, error: null);
    final phone = state.phone;
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(
          isLoading: false, error: 'No phone found. Please login again.');
      return false;
    }
    try {
      final ok = await _service.unsubscribe(phone);
      if (ok) {
        await _clearSession();
        return true;
      }
      state = state.copyWith(
          isLoading: false, error: 'Unsubscribe failed. Please try again.');
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async => _clearSession();

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bdapps_phone');
    state = const AuthState();
  }
}

final _authServiceProvider = Provider((_) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(_authServiceProvider)),
);
```

**Important nuance:** unlike Firebase (which has its own persistent session under the hood via the SDK), this custom gate manually persists just the **phone number** string in `SharedPreferences` under the key `bdapps_phone`. Presence of that key = "subscribed" from the app's point of view. There is intentionally **no periodic re-validation against the server** — once verified, the app trusts local storage until an explicit unsubscribe. If you need server-truth revalidation (e.g. because a user might get unsubscribed server-side without using the app, like a failed billing cycle), add a background check in `_loadSession()` that re-calls a "check status" endpoint and clears the session if it comes back inactive.

### 4.4 UI screens

Three screens, in sequence: `SubscriptionScreen` → `PhoneScreen` → `OtpScreen`.

**`SubscriptionScreen`** (`lib/features/auth/screens/subscription_screen.dart`) — a marketing/paywall screen. Stateless. Shows app branding, pricing (`৳2.78 / ৳5.56` per day for Robi/Airtel respectively), a feature list, and a single "Subscribe with Mobile" button that pushes `PhoneScreen`. No provider interaction here — it's pure UI.

**`PhoneScreen`** (`lib/features/auth/screens/phone_screen.dart`) — collects an 11-digit phone number, validates the prefix is `018` (Robi) or `016` (Airtel):
```dart
validator: (v) {
  final d = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length < 11) return 'Enter 11-digit number';
  final prefix = d.substring(0, 3);
  if (prefix != '018' && prefix != '016') {
    return 'Robi (018) or Airtel (016) only';
  }
  return null;
},
```
On submit, calls `ref.read(authProvider.notifier).sendOtp(phone)`, then on success pushes `OtpScreen(phone: phone)`.

**`OtpScreen`** (`lib/features/auth/screens/otp_screen.dart`) — a 6-box OTP input (auto-advances focus per digit, auto-submits on the 6th digit). On submit, calls `ref.read(authProvider.notifier).verifyOtp(code)`. On success:
```dart
// Pop the entire auth navigator stack back to root.
// main.dart watches authProvider and will transition to the next flow step.
Navigator.of(context).popUntil((route) => route.isFirst);
```
This is the key mechanism: **the screen doesn't navigate to the next step itself** — it just pops back to root, and the top-level flow-state-machine widget (watching `authProvider` reactively) notices `isAuthenticated` flipped to `true` and re-renders to the next gate automatically. See §6.

---

## 5. Gate 2 — Firebase Authentication

### 5.1 `FirebaseAuthService` (raw Firebase layer)

Full file — `lib/features/auth/services/firebase_auth_service.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // serverClientId comes from the Web OAuth client in google-services.json
  // (the oauth_client entry with client_type: 3). Required on Android so
  // google_sign_in can produce an idToken Firebase can verify.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '798717939681-mij6dfmkkjqgtg1rj2ptb34khab5dfpd.apps.googleusercontent.com',
  );

  User? get currentUser => _auth.currentUser;

  bool get isGoogleUser {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  Future<User> signInWithEmailPassword(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return cred.user!;
  }

  Future<User> registerWithEmailPassword(
      String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user!.updateDisplayName(name);
    await cred.user!.reload();
    return _auth.currentUser!; // reload so displayName is populated
  }

  Future<User> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return cred.user!;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser!;
    final cred =
        EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(cred);
  }

  Future<void> reauthenticateWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await _auth.currentUser!.reauthenticateWithCredential(credential);
  }

  Future<void> updatePassword(String newPassword) =>
      _auth.currentUser!.updatePassword(newPassword);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> deleteAccount() async => _auth.currentUser!.delete();
}
```

**Replace `serverClientId`** with your own Firebase project's Web client ID (found in `google-services.json` under `oauth_client` where `client_type == 3`, or in Firebase Console → Project Settings → General → Web SDK configuration → look for the associated Google Cloud OAuth client).

### 5.2 `FirebaseAuthNotifier` / `firebaseAuthProvider` (state layer)

Full file — `lib/features/auth/providers/firebase_auth_provider.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_auth_service.dart';

class FirebaseAuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const FirebaseAuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null;

  FirebaseAuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
  }) =>
      FirebaseAuthState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class FirebaseAuthNotifier extends StateNotifier<FirebaseAuthState> {
  final FirebaseAuthService _service;

  FirebaseAuthNotifier(this._service) : super(const FirebaseAuthState()) {
    // Firebase persists its own session (SDK-level, survives app restarts) —
    // just read whatever's already signed in on notifier construction.
    final current = _service.currentUser;
    if (current != null) state = FirebaseAuthState(user: current);
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _service.signInWithEmailPassword(email, password);
      state = FirebaseAuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  Future<bool> registerWithEmailPassword(
      String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user =
          await _service.registerWithEmailPassword(name, email, password);
      state = FirebaseAuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _service.signInWithGoogle();
      state = FirebaseAuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.sendPasswordReset(email.trim());
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const FirebaseAuthState();
  }

  // Returns true if delete succeeded.
  // Pass password for email users; null for Google users (re-auth via Google).
  Future<bool> deleteAccount({String? password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (_service.isGoogleUser) {
        await _service.reauthenticateWithGoogle();
      } else {
        if (password == null || password.isEmpty) {
          state = state.copyWith(isLoading: false, error: 'Password required');
          return false;
        }
        await _service.reauthenticateWithPassword(password);
      }
      await _service.deleteAccount();
      state = const FirebaseAuthState();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.reauthenticateWithPassword(currentPassword);
      await _service.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
      return false;
    }
  }

  // Firebase requires "recent login" for sensitive ops (delete, password
  // change) — this maps raw FirebaseAuthException codes to user-friendly text.
  String _friendly(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'Incorrect email or password. Please try again.',
        'user-not-found' => 'No account found with this email.',
        'email-already-in-use' =>
          'This email is already registered. Please log in instead.',
        'weak-password' => 'Password must be at least 6 characters.',
        'invalid-email' => 'Invalid email address.',
        'operation-not-allowed' =>
          'Email/password sign-in is not enabled. Please enable it in Firebase Console → Authentication → Sign-in methods.',
        'network-request-failed' =>
          'Network error. Please check your connection.',
        'too-many-requests' =>
          'Too many attempts. Please wait a moment and try again.',
        'user-disabled' => 'This account has been disabled.',
        'requires-recent-login' =>
          'Please log out and log in again before making this change.',
        _ => e.message ?? e.code,
      };
    }
    final msg = e.toString();
    if (msg.contains('cancelled')) return 'Sign-in cancelled.';
    return msg
        .replaceFirst('Exception: ', '')
        .replaceAll(RegExp(r'\[firebase_auth[^\]]*\]'), '')
        .trim();
  }
}

final _firebaseAuthServiceProvider = Provider((_) => FirebaseAuthService());

final firebaseAuthProvider =
    StateNotifierProvider<FirebaseAuthNotifier, FirebaseAuthState>(
  (ref) => FirebaseAuthNotifier(ref.watch(_firebaseAuthServiceProvider)),
);
```

Note this notifier does **not** subscribe to `FirebaseAuth.instance.authStateChanges()` as a stream — it reads `currentUser` once at construction and otherwise updates its own state imperatively after each auth action. This is simpler but means external changes to the Firebase session (e.g. token revoked server-side) won't reactively update the UI until the next explicit auth action. If you want that reactivity, replace the constructor body with a `StreamSubscription` on `authStateChanges()`.

### 5.3 UI: `LoginRegisterScreen`

`lib/features/auth/screens/login_register_screen.dart` — a single screen with a `TabBar` (Login / Register), each tab a separate `ConsumerStatefulWidget` (`_LoginTab`, `_RegisterTab`) with its own `Form`/`GlobalKey<FormState>`.

**Login tab fields:** email, password (with show/hide toggle), "Forgot Password?" link (opens `ForgotPasswordSheet` bottom sheet), primary "Login" button, an "OR" divider, then a Google sign-in button.

```dart
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;
  final ok = await ref
      .read(firebaseAuthProvider.notifier)
      .signInWithEmailPassword(_emailCtrl.text.trim(), _passCtrl.text);
  if (!mounted) return;
  if (!ok) {
    final err = ref.read(firebaseAuthProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Login failed'),
        backgroundColor: TagColors.missed));
  }
  // No explicit navigation on success — main.dart watches
  // firebaseAuthProvider.isLoggedIn and re-renders automatically.
}
```

**Register tab fields:** full name, email, password (min 6 chars, validated client-side), confirm password (must match), then the same primary button / divider / Google button pattern.

```dart
Future<void> _register() async {
  if (!_formKey.currentState!.validate()) return;
  final ok = await ref
      .read(firebaseAuthProvider.notifier)
      .registerWithEmailPassword(
          _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
  if (!mounted) return;
  if (!ok) { /* show error snackbar, same pattern as login */ }
}
```

**Google sign-in** (identical on both tabs):
```dart
Future<void> _googleSignIn() async {
  final ok = await ref.read(firebaseAuthProvider.notifier).signInWithGoogle();
  if (!mounted) return;
  if (!ok) {
    final err = ref.read(firebaseAuthProvider).error;
    if (err != null && !err.contains('cancelled')) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: TagColors.missed));
    }
  }
}
```
Note: cancellation (`err.contains('cancelled')`) is deliberately **not** shown as an error snackbar — the user just tapped away from the Google account picker, that's not a failure worth surfacing.

Again — **no explicit `Navigator` call after successful login/register/Google sign-in**. Because `firebaseAuthProvider` is watched reactively at the top level (`main.dart`), flipping `isLoggedIn` to `true` alone triggers the flow transition. This "reactive gate, not imperative navigation" pattern is the core idiom of this whole architecture — replicate it exactly, it avoids a whole class of navigation bugs (double-pushes, wrong screen after async gaps, etc.).

### 5.4 Logout & Unsubscribe (from Settings/Profile screen)

`lib/features/settings/presentation/screens/profile_screen.dart` has two destructive-ish actions, both gated behind a confirmation dialog:

```dart
final authNotifier = ref.read(authProvider.notifier);
final fbNotifier = ref.read(firebaseAuthProvider.notifier);

// ── Logout ─────────────────────────────────────────────────────────
_ActionTile(
  icon: Icons.logout_rounded,
  label: 'Logout',
  subtitle: 'Sign out — subscription stays active',
  onTap: () async {
    final ok = await _confirm(context,
        title: 'Logout?',
        message: 'You will be signed out and redirected to the login '
            'screen. Your BdApps subscription remains active.',
        confirmLabel: 'Logout');
    if (ok) await fbNotifier.signOut();
    // Firebase-only sign out. authProvider (subscription) is untouched,
    // so main.dart's flow gate sends the user straight to LoginRegisterScreen
    // (Gate 1 still passes), not back to the paywall.
  },
),

// ── Unsubscribe ────────────────────────────────────────────────────
_ActionTile(
  icon: Icons.unsubscribe_rounded,
  label: 'Unsubscribe',
  subtitle: 'Cancel BdApps subscription and sign out',
  onTap: () async {
    final ok = await _confirm(context,
        title: 'Unsubscribe?',
        message: 'Your BdApps subscription will be cancelled. You will '
            'need to subscribe again to use the app.',
        confirmLabel: 'Unsubscribe',
        destructive: true);
    if (!ok || !context.mounted) return;
    final unsubOk = await authNotifier.unsubscribe();
    if (unsubOk) {
      await fbNotifier.signOut(); // also sign out of Firebase
    } else if (context.mounted) {
      final err = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Unsubscribe failed')),
      );
    }
  },
),
```

Key behavior: **Logout only clears Gate 2**, so the user re-lands on the login screen (not the paywall) next launch. **Unsubscribe clears both Gate 1 and Gate 2** (it signs out of Firebase too, since there's no reason to stay logged in to an app you're no longer subscribed to) — the user re-lands on the paywall.

### 5.5 Account deletion also cancels the subscription

```dart
await authNotifier.unsubscribe();
final deleted = await fbNotifier.deleteAccount(password: password);
```

When a user permanently deletes their Firebase account, the subscription is cancelled first as a courtesy (so they don't keep getting billed for an app they can no longer log into). Do the unsubscribe call *before* `deleteAccount()` while you still have a valid session to attribute it to.

---

## 6. The flow-gate state machine (`main.dart`)

This is the piece that ties both gates together. It lives in the app's root `ConsumerStatefulWidget` (here, `MedRemindApp`).

### 6.1 State shape

```dart
class _MedRemindAppState extends ConsumerState<MedRemindApp> {
  // null = loading, 'sub' = not subscribed, 'login' = not logged in,
  // 'intro' = onboarding intro, 'perm' = permission requests,
  // true = fully authenticated, show main app
  Object? _flow;
```

Using `Object?` with a mix of `null`/`String`/`bool` as a poor-man's sealed union is a stylistic choice in this codebase — feel free to replace with a proper `enum` in a fresh implementation; the logic is what matters.

### 6.2 Resolving the flow on launch

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) => _resolveFlow());
}

Future<void> _resolveFlow() async {
  // Let AuthNotifier._loadSession() (a microtask kicked off in its own
  // constructor) finish reading SharedPreferences before checking it.
  await Future.microtask(() {});
  if (!mounted) return;

  final auth = ref.read(authProvider);           // Gate 1: subscription
  if (!auth.isAuthenticated) {
    setState(() => _flow = 'sub');
    return;
  }

  final firebase = ref.read(firebaseAuthProvider); // Gate 2: Firebase login
  if (!firebase.isLoggedIn) {
    setState(() => _flow = 'login');
    return;
  }

  final prefs = ref.read(sharedPrefsProvider);
  final introDone = await _isIntroDone(prefs);      // Gate 3: onboarding
  final permsDone = await isOnboardingDone();

  if (!mounted) return;
  if (!introDone) {
    setState(() => _flow = 'intro');
  } else if (!permsDone) {
    setState(() => _flow = 'perm');
  } else {
    setState(() => _flow = true); // fully authenticated → main app
  }
}
```

### 6.3 Reactive re-evaluation on `build()`

This is the part that makes screens *not* need explicit post-success navigation calls. `build()` **watches** both providers, and whenever their state changes such that the current `_flow` value is no longer valid, it schedules a transition for the *next* frame (never call `setState` synchronously inside `build`):

```dart
@override
Widget build(BuildContext context) {
  final auth = ref.watch(authProvider);
  final firebase = ref.watch(firebaseAuthProvider);

  // Subscription lost while inside the main app → back to paywall.
  if (_flow == true && !auth.isAuthenticated) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => setState(() => _flow = 'sub'));
  }
  // Firebase logged out while inside the main app → back to login.
  if (_flow == true && auth.isAuthenticated && !firebase.isLoggedIn) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => setState(() => _flow = 'login'));
  }
  // Just subscribed (was on paywall) → advance to the next gate.
  if (_flow == 'sub' && auth.isAuthenticated) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _flow = null); // brief loader
      _resolveFlow();
    });
  }
  // Just logged in (was on login screen) → advance to the next gate.
  if (_flow == 'login' && firebase.isLoggedIn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _flow = null);
      _resolveFlow();
    });
  }

  Widget home;
  if (_flow == null) {
    home = const Scaffold(body: Center(child: CircularProgressIndicator()));
  } else if (_flow == 'sub') {
    home = const SubscriptionScreen();
  } else if (_flow == 'login') {
    home = const LoginRegisterScreen();
  } else if (_flow == 'intro') {
    home = OnboardingIntroScreen(onDone: () async {
      await _markIntroDone(ref.read(sharedPrefsProvider));
      setState(() => _flow = 'perm');
    });
  } else if (_flow == 'perm') {
    home = PermissionOnboardingScreen(
        onComplete: () => setState(() => _flow = true));
  } else {
    // _flow == true: full main app, using go_router from here on.
    return MaterialApp.router(
      title: 'MedRemind',
      routerConfig: appRouter,
      // ...theme etc.
    );
  }

  // ValueKey forces a brand-new Navigator (clearing any pushed routes,
  // e.g. PhoneScreen/OtpScreen still on the stack) every time _flow changes.
  return MaterialApp(
    key: ValueKey(_flow),
    home: home,
    // ...theme etc.
  );
}
```

**Why `ValueKey(_flow)` matters:** when the user is on `OtpScreen` (pushed on top of `SubscriptionScreen`/`PhoneScreen`) and verification succeeds, `OtpScreen` calls `Navigator.popUntil((route) => route.isFirst)` to collapse its own stack, then the flow watcher swaps `_flow` from `'sub'` to `'login'`. Without the `ValueKey`, Flutter would try to *diff* the old `MaterialApp`/`Navigator` tree against the new one and could get confused about which routes should still exist. The `ValueKey` forces a full remount of the `Navigator` for every flow transition, guaranteeing a clean single-route stack at every gate.

**Why `_flow = null` (loader) as an intermediate step:** when advancing from `'sub'` → next gate, or `'login'` → next gate, the code briefly sets `_flow = null` (showing a spinner) *before* calling `_resolveFlow()` again, rather than jumping directly to a guessed next state. This is because the next gate depends on *async* checks (SharedPreferences reads for onboarding state) that can't be resolved synchronously inside `build()`.

### 6.4 `sharedPrefsProvider`

A `Provider<SharedPreferences>` is overridden at the root once `SharedPreferences.getInstance()` resolves in `main()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const MedRemindApp(),
  ));
}
```
(`sharedPrefsProvider` itself is declared elsewhere, typically as `final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());` — the override at `runApp` is what actually supplies it.)

---

## 7. File structure to replicate

```
lib/
  features/
    auth/
      services/
        auth_service.dart              # Gate 1: raw HTTP calls to subscription backend
        firebase_auth_service.dart      # Gate 2: raw FirebaseAuth + GoogleSignIn calls
      providers/
        auth_provider.dart              # Gate 1: AuthState/AuthNotifier/authProvider
        firebase_auth_provider.dart     # Gate 2: FirebaseAuthState/Notifier/Provider
      screens/
        subscription_screen.dart        # Paywall / marketing screen
        phone_screen.dart               # Phone number entry
        otp_screen.dart                 # 6-digit OTP entry
        login_register_screen.dart      # Login/Register tabs (Firebase)
      widgets/
        auth_form_widgets.dart          # Shared AuthInputField/AuthPrimaryButton/etc.
        forgot_password_sheet.dart      # Password reset bottom sheet
  main.dart                             # Flow-gate state machine (ties both gates together)
  firebase_options.dart                 # Generated by `flutterfire configure`
```

---

## 8. Checklist to reproduce this in a new app

1. `flutter pub add flutter_riverpod shared_preferences http firebase_core firebase_auth google_sign_in`
2. Create a Firebase project, run `flutterfire configure`, enable Email/Password + Google sign-in methods.
3. Copy `firebase_auth_service.dart` and `firebase_auth_provider.dart` verbatim; swap in your own `serverClientId`.
4. Build `login_register_screen.dart` (or adapt the one here) wired to `firebaseAuthProvider`.
5. Decide what your Gate 1 actually is:
   - If you also need real carrier billing, get the OTP/subscription API contract from your billing aggregator and implement `auth_service.dart` to match (endpoints will differ from this app's, but keep the `sendOtp`/`verifyOtp`/`unsubscribe` shape).
   - If you don't need a subscription gate at all, skip Gate 1 entirely and start the flow machine at Gate 2.
   - If you need a different kind of entitlement (Play Store subscription, license key, trial), replace the HTTP calls inside `auth_service.dart` but keep `auth_provider.dart`'s shape (`isAuthenticated` boolean, `unsubscribe()`/`logout()` methods) so the rest of the plumbing doesn't change.
6. Copy `main.dart`'s `_MedRemindAppState` flow-gate logic verbatim, adjusting the `_flow` states to match whichever gates you actually have (you can delete the `'sub'` branch entirely if you skip Gate 1).
7. Wire Settings/Profile screen actions for Logout (`firebaseAuthProvider.notifier.signOut()`) and Unsubscribe (`authProvider.notifier.unsubscribe()` then `firebaseAuthProvider.notifier.signOut()`), each behind a confirmation dialog.
8. Test the full matrix: fresh install → subscribe → register → onboarding → main app; then logout → re-login (subscription should still be intact, skip straight past Gate 1); then unsubscribe → confirm both gates are cleared and app returns to the paywall.
