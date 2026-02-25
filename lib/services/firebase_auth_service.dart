import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AppFirebaseAuthException implements Exception {
  const AppFirebaseAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseAuthSession {
  const FirebaseAuthSession({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.idToken,
    required this.emailVerified,
  });

  final String uid;
  final String email;
  final String displayName;
  final String idToken;
  final bool emailVerified;
}

class FirebaseAuthService {
  const FirebaseAuthService();

  static const String _androidPackageName = 'com.blackpiratex.book';

  Future<FirebaseAuthSession> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final auth = await _auth();
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AppFirebaseAuthException('Sign-in failed. Try again.');
      }
      return _sessionFromUser(user, forceRefresh: true);
    } on FirebaseAuthException catch (e) {
      throw AppFirebaseAuthException(_messageForFirebaseAuthError(e));
    }
  }

  Future<FirebaseAuthSession> signInWithGoogle() async {
    final auth = await _auth();
    try {
      final googleUser = await GoogleSignIn(
        scopes: const <String>['email'],
      ).signIn();
      if (googleUser == null) {
        throw const AppFirebaseAuthException('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken?.trim() ?? '';
      if (idToken.isEmpty) {
        throw const AppFirebaseAuthException(
          'Google sign-in did not return an ID token.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      final result = await auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const AppFirebaseAuthException(
          'Google sign-in failed. Try again.',
        );
      }
      return _sessionFromUser(user, forceRefresh: true);
    } on FirebaseAuthException catch (e) {
      throw AppFirebaseAuthException(_messageForFirebaseAuthError(e));
    }
  }

  Future<FirebaseAuthSession> signUpWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final auth = await _auth();
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      var user = credential.user;
      if (user == null) {
        throw const AppFirebaseAuthException('Sign-up failed. Try again.');
      }
      final trimmedName = displayName.trim();
      if (trimmedName.isNotEmpty) {
        await user.updateDisplayName(trimmedName);
        await user.reload();
        user = auth.currentUser ?? user;
      }
      if (!user.emailVerified) {
        final actionCodeSettings = _defaultEmailActionSettings();
        if (actionCodeSettings == null) {
          await user.sendEmailVerification();
        } else {
          await user.sendEmailVerification(actionCodeSettings);
        }
      }
      return _sessionFromUser(user, forceRefresh: true);
    } on FirebaseAuthException catch (e) {
      throw AppFirebaseAuthException(_messageForFirebaseAuthError(e));
    }
  }

  Future<FirebaseAuthSession?> currentSession({
    bool forceRefresh = false,
  }) async {
    final auth = await _auth();
    final user = auth.currentUser;
    if (user == null) return null;
    try {
      return await _sessionFromUser(user, forceRefresh: forceRefresh);
    } on FirebaseAuthException catch (e) {
      throw AppFirebaseAuthException(_messageForFirebaseAuthError(e));
    }
  }

  Future<void> signOut() async {
    final auth = await _auth();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Firebase sign-out below still clears app auth state.
    }
    await auth.signOut();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final auth = await _auth();
    try {
      await auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: _defaultEmailActionSettings(),
      );
    } on FirebaseAuthException catch (e) {
      throw AppFirebaseAuthException(_messageForFirebaseAuthError(e));
    }
  }

  Future<FirebaseAuth> _auth() async {
    await _ensureInitialized();
    return FirebaseAuth.instance;
  }

  ActionCodeSettings? _defaultEmailActionSettings() {
    if (Firebase.apps.isEmpty) return null;
    final projectId = Firebase.app().options.projectId.trim();
    if (projectId.isEmpty) return null;

    // Use Firebase Hosting's default auth action handler domain so password
    // reset and verification emails are generated with a valid continue URL.
    return ActionCodeSettings(
      url: 'https://$projectId.firebaseapp.com/__/auth/action',
      handleCodeInApp: false,
      androidPackageName: _androidPackageName,
      androidInstallApp: false,
    );
  }

  Future<void> _ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      throw AppFirebaseAuthException(
        e.message ??
            'Firebase is not configured yet. Add your Firebase Android app config and try again.',
      );
    }
  }

  Future<FirebaseAuthSession> _sessionFromUser(
    User user, {
    required bool forceRefresh,
  }) async {
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.trim().isEmpty) {
      throw const AppFirebaseAuthException(
        'Failed to get Firebase ID token. Try signing in again.',
      );
    }
    return FirebaseAuthSession(
      uid: user.uid,
      email: (user.email ?? '').trim(),
      displayName: (user.displayName ?? '').trim(),
      idToken: token.trim(),
      emailVerified: user.emailVerified,
    );
  }
}

String _messageForFirebaseAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'Enter a valid email address.';
    case 'email-already-in-use':
      return 'That email is already in use.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email or password is incorrect.';
    case 'too-many-requests':
      return 'Too many attempts. Try again later.';
    case 'network-request-failed':
      return 'Network error while contacting Firebase.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled in Firebase.';
    case 'requires-recent-login':
      return 'Please sign in again and retry.';
    case 'missing-email':
      return 'Enter your email address first.';
    case 'invalid-continue-uri':
    case 'missing-continue-uri':
      return 'Firebase email link URL is invalid. Check Auth email action URL settings.';
    case 'unauthorized-continue-uri':
      return 'Firebase blocked the email link URL. Add the domain in Auth -> Settings -> Authorized domains.';
    case 'missing-android-pkg-name':
    case 'invalid-dynamic-link-domain':
      return 'Firebase email action settings are incomplete. Check Android package and auth link domain settings.';
    default:
      return error.message ?? 'Authentication failed.';
  }
}
