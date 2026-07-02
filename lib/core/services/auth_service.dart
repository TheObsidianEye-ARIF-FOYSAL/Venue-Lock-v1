import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Web OAuth client ID (client_type: 3 in google-services.json) — required
// on Android so google_sign_in can produce an idToken Firebase can verify.
const _kGoogleServerClientId =
    '581574614677-lgh88bfkr367594rshhf1cd67u2aa3k7.apps.googleusercontent.com';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleSignInInit;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String get adminEmail => _auth.currentUser?.email ?? '';
  String get displayName =>
      _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? '';
  bool get isGoogleUser => _auth.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  AuthService() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInit ??= _googleSignIn.initialize(
      serverClientId: _kGoogleServerClientId,
    );
  }

  Future<String?> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    } catch (_) {
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    } catch (_) {
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: show a popup window
        final credential =
            await _auth.signInWithPopup(GoogleAuthProvider());
        if (credential.user == null) return 'Google sign-in failed.';
        notifyListeners();
        return null;
      }

      // Android / iOS: use the native Google account picker instead of a
      // browser-based OAuth screen.
      await _ensureGoogleSignInInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return 'Google sign-in failed.';

      final googleCredential = GoogleAuthProvider.credential(idToken: idToken);
      final credential = await _auth.signInWithCredential(googleCredential);
      if (credential.user == null) return 'Google sign-in failed.';
      notifyListeners();
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Sign-in cancelled.';
      }
      return 'Google sign-in failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    } catch (_) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    notifyListeners();
  }

  /// Deletes the signed-in user's Firebase account. Firebase requires a
  /// "recent login" for this sensitive operation, so the caller must
  /// re-authenticate first: pass [password] for email/password accounts,
  /// or nothing for Google accounts (re-authenticated via Google instead).
  /// Returns a user-facing error message, or null on success.
  Future<String?> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return 'No account is signed in.';
    try {
      if (isGoogleUser) {
        await _reauthenticateWithGoogle(user);
      } else {
        if (password == null || password.isEmpty) {
          return 'Password required to confirm deletion.';
        }
        await _reauthenticateWithPassword(user, password);
      }
      await user.delete();
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      notifyListeners();
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Sign-in cancelled.';
      }
      return 'Google sign-in failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    } catch (_) {
      return 'Account deletion failed. Please try again.';
    }
  }

  Future<void> _reauthenticateWithPassword(User user, String password) async {
    final credential =
        EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    await _ensureGoogleSignInInitialized();
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception('Google sign-in failed.');
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
  }

  static String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email. Please register first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'popup-closed-by-user':
        return 'Sign-in popup was closed. Please try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
