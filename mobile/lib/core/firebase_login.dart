import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

/// The Firebase project the app signs in with (Firebase console → Project
/// settings → Your apps). These values are public: they only name the
/// project. Security comes from Firebase and from the backend checking every
/// sign-in. Override any of them at build time with
/// `--dart-define=FIREBASE_API_KEY=…` and so on.
///
/// Project: surefix-app. Where an app id is empty (e.g. a platform not yet
/// registered in Firebase), that build uses SureFix's own email + password
/// login instead.
abstract final class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIzaSyAVTI0rMXIIs7PsIOZKAkJ4SHgQIKwOyys');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'surefix-app');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_SENDER_ID', defaultValue: '552777580802');
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID', defaultValue: '1:552777580802:web:eedb7cf3c1e2dc8f85421b');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '');

  static String get authDomain => '$projectId.firebaseapp.com';

  /// The app id for this platform, or '' where Firebase isn't set up.
  static String get appId {
    if (kIsWeb) return webAppId;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => androidAppId,
      TargetPlatform.iOS => iosAppId,
      _ => '', // desktop builds use the backend's own login
    };
  }

  static bool get configured => apiKey.isNotEmpty && projectId.isNotEmpty && appId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: kIsWeb ? authDomain : null,
      );
}

/// Sign-in with Firebase Authentication: Firebase checks passwords and sends
/// password-reset emails; the backend turns each Firebase sign-in into a
/// SureFix session (POST /api/auth/firebase).
abstract final class FirebaseLogin {
  static bool _ready = false;

  /// True when this build signs in with Firebase.
  static bool get active => _ready;

  static Future<void> init() async {
    if (!FirebaseConfig.configured || _ready) return;
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      _ready = true;
    } catch (e) {
      debugPrint('Firebase unavailable, using the backend login: $e');
    }
  }

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Signs in and returns the Firebase ID token for the backend.
  static Future<String> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return (await cred.user!.getIdToken())!;
    } on FirebaseAuthException catch (e) {
      throw explain(e);
    }
  }

  /// Creates the Firebase account (or signs in, if an earlier attempt
  /// created it) and returns its ID token. Sends a verification email.
  static Future<String> signUp(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      cred.user!.sendEmailVerification().catchError((_) {});
      return (await cred.user!.getIdToken())!;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Either a half-finished sign-up of theirs, or someone else's account.
        try {
          return await signIn(email, password);
        } on ApiError {
          throw ApiError(409, 'An account with this email already exists. Log in instead, or reset the password.');
        }
      }
      throw explain(e);
    }
  }

  /// A new ID token after re-reading the account (e.g. once the email
  /// verification link was opened).
  static Future<String> freshToken() async {
    final user = _auth.currentUser!;
    try {
      await user.reload();
      return (await _auth.currentUser!.getIdToken(true))!;
    } on FirebaseAuthException catch (e) {
      throw explain(e);
    }
  }

  /// Emails the verification link again.
  static Future<void> sendVerification(String email, String password) async {
    try {
      if (_auth.currentUser?.email?.toLowerCase() != email.trim().toLowerCase()) await signIn(email, password);
      await _auth.currentUser!.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw explain(e);
    }
  }

  /// Emails a link to choose a new password.
  static Future<void> sendReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Don't reveal whether the address has an account.
      if (e.code == 'user-not-found') return;
      throw explain(e);
    }
  }

  /// Whether the signed-in account is a Firebase one (else: backend login).
  static bool get signedIn => _ready && _auth.currentUser != null;

  static Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser!;
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email ?? '', password: current));
      await user.updatePassword(next);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') throw ApiError(400, 'Current password is incorrect');
      throw explain(e);
    }
  }

  static Future<void> signOut() async {
    if (!_ready) return;
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Firebase's error codes in the app's words.
  static ApiError explain(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' =>
          ApiError(401, 'Invalid email or password', code: 'firebase_${e.code}'),
        'user-disabled' => ApiError(403, 'Your account has been suspended. Contact support.', code: 'suspended'),
        'too-many-requests' => ApiError(429, 'Too many attempts. Please wait a few minutes and try again.'),
        'weak-password' => ApiError(400, 'Choose a stronger password (at least 6 characters).'),
        'network-request-failed' => ApiError(0, "Can't reach SureFix. Check your connection."),
        'operation-not-allowed' => ApiError(400, 'Email sign-in is not enabled for this Firebase project.'),
        _ => ApiError(400, e.message ?? 'Sign-in failed. Please try again.'),
      };
}
