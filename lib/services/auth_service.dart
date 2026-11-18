import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_constants.dart';

/// Thrown when the shared demo account cannot be reached or created.
class DemoUnavailableException implements Exception {
  const DemoUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around Firebase Auth with friendly error messages.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final UserCredential credential = await _auth
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
    final User? user = credential.user;
    if (user != null && name.trim().isNotEmpty) {
      await user.updateDisplayName(name.trim());
    }
    return credential;
  }

  /// One-tap demo entry used by panelists: signs in with the shared demo
  /// credentials and creates them on first use.
  Future<UserCredential> signInToDemo() async {
    try {
      return await signIn(
        email: AppConstants.demoEmail,
        password: AppConstants.demoPassword,
      );
    } on FirebaseAuthException catch (error) {
      if (!_isMissingAccount(error)) rethrow;

      try {
        return await signUp(
          name: AppConstants.demoName,
          email: AppConstants.demoEmail,
          password: AppConstants.demoPassword,
        );
      } on FirebaseAuthException catch (signUpError) {
        if (signUpError.code == 'email-already-in-use') {
          throw const DemoUnavailableException(
            'The demo account already exists with a different password. '
            'Please log in or create your own account.',
          );
        }
        rethrow;
      }
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  static bool _isMissingAccount(FirebaseAuthException error) {
    return const <String>{
      'user-not-found',
      'invalid-credential',
      'invalid-login-credentials',
      'wrong-password',
    }.contains(error.code);
  }

  /// Maps Firebase failures to sentences a student can act on.
  static String messageFor(Object error) {
    if (error is DemoUnavailableException) return error.message;
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already exists for that email. Try logging in.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'operation-not-allowed':
          return 'Email sign-in is not enabled for this Firebase project yet.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again in a moment.';
        case 'network-request-failed':
          return 'No connection. Check your internet and try again.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
