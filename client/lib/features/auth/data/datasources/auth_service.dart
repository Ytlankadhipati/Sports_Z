import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '542925608787-25g78aqgj1ddr9iaiq4fp1j1p8gkkgq4.apps.googleusercontent.com',
  );

  User? get currentUser => _firebaseAuth.currentUser;

  Future<bool> isEmailVerified() async {
    User? user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload().timeout(const Duration(seconds: 10));
    user = _firebaseAuth.currentUser;
    return user?.emailVerified ?? false;
  }

  bool isGoogleUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 20));
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email';
        case 'wrong-password':
          return 'Incorrect password';
        case 'invalid-email':
          return 'Invalid email address';
        case 'invalid-credential':
          return 'Invalid email or password';
        default:
          return 'Login failed: ${e.message}';
      }
    } on TimeoutException {
      return 'Login timed out. Check your connection and try again.';
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account already exists with this email';
        case 'weak-password':
          return 'Password is too weak';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return 'Signup failed: ${e.message}';
      }
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> resendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        return null;
      }
      return 'No user found';
    } catch (e) {
      return 'Failed to send email: $e';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signIn()
          .timeout(const Duration(seconds: 20));
      if (googleUser == null) return 'Sign in cancelled';

      final GoogleSignInAuthentication googleAuth = await googleUser
          .authentication
          .timeout(const Duration(seconds: 10));

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 20));
      return null;
    } on TimeoutException {
      return 'Google sign-in timed out. Check your connection and try again.';
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('10') ||
          errorStr.toLowerCase().contains('developer_error')) {
        return 'Google Sign-in failed (ApiException: 10): SHA-1 fingerprint is missing in Firebase Console.';
      }
      return 'Google sign-in failed: $e';
    }
  }

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(String error) onError,
    required Function() onAutoVerified,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _firebaseAuth.signInWithCredential(credential);
        onAutoVerified();
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<String?> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _firebaseAuth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-verification-code':
          return 'Invalid OTP. Please try again.';
        case 'session-expired':
          return 'OTP expired. Please request a new one.';
        default:
          return 'Verification failed: ${e.message}';
      }
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> getFirebaseIdToken() async =>
      await _firebaseAuth.currentUser?.getIdToken();

  Future<void> saveBackendSession({
    required String token,
    required String userId,
    String? role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('backend_user_id', userId);
    if (role != null) {
      await prefs.setString('backend_role', role);
    } else {
      await prefs.remove('backend_role');
    }
  }

  Future<void> clearBackendSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('backend_user_id');
    await prefs.remove('backend_role');
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut().timeout(const Duration(seconds: 5));
    } finally {
      await clearBackendSession();
      try {
        await _googleSignIn.signOut().timeout(const Duration(seconds: 3));
      } catch (_) {
        // Firebase and backend session state are already cleared locally.
      }
    }
  }

  // ===================== PASSWORD RESET & ACCOUNT LINKING =====================

  /// A06: Password Reset Email bhejta hai
  Future<String?> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'invalid-email':
          return 'The email address is badly formatted.';
        default:
          return e.message ?? 'Failed to send reset email.';
      }
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// A08: Current user ke linked auth providers (e.g. google.com, password, phone)
  List<String> getLinkedProviders() {
    final user = _firebaseAuth.currentUser;
    if (user == null) return [];
    return user.providerData.map((info) => info.providerId).toList();
  }

  /// A08: Existing account me Google Account link karta hai
  Future<String?> linkWithGoogle() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return 'No user signed in.';

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Google link cancelled';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.linkWithCredential(credential);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'provider-already-linked':
          return 'This Google account is already linked.';
        case 'credential-already-in-use':
          return 'This Google account is already registered with another user.';
        case 'email-already-in-use':
          return 'An account already exists with this Google email.';
        default:
          return e.message ?? 'Failed to link Google account.';
      }
    } catch (e) {
      return 'Unexpected error while linking: $e';
    }
  }
}
