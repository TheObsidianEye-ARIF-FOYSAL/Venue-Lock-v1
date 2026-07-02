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
      final provider = GoogleAuthProvider();
      UserCredential credential;

      if (kIsWeb) {
        // Web: show a popup window
        credential = await _auth.signInWithPopup(provider);
      } else {
        // Android / iOS: opens a browser-based consent screen
        credential = await _auth.signInWithProvider(provider);
      }

      if (credential.user == null) return 'Google sign-in failed.';
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyError(e.code);
    } catch (_) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
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
