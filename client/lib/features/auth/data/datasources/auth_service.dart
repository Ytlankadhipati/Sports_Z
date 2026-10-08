import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_z/core/config/api_config.dart';

import 'dart:convert';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static String get baseUrl => ApiConfig.baseUrl;
  static String get _apiV1 => '${ApiConfig.baseUrl}/v1';
  static const Duration _timeout = Duration(seconds: 8);

  User? get currentUser => _firebaseAuth.currentUser;

  Future<bool> isEmailVerified() async {
    User? user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload();
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
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Sign in cancelled';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      return null;
    } catch (e) {
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

  // ===================== BACKEND INTEGRATION (NAYA) =====================

  /// Firebase se ID token leke backend ke /auth/verify ko bhejta hai.
  /// Backend MongoDB me user find/create karke apna JWT deta hai.
  /// Success -> {token, user_id, role} return karta hai, warna null.
  Future<Map<String, dynamic>?> verifyWithBackend() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken();
      final response = await http
          .post(
            Uri.parse('$_apiV1/auth/verify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveSession(
          token: data['token'],
          userId: data['user_id'],
          role: data['role'],
        );
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Role Selection screen se backend ko role batata hai.
  Future<Map<String, dynamic>?> selectRoleOnBackend(String role) async {
    try {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) return null;
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) return null;

      final response = await http
          .post(
            Uri.parse('$_apiV1/auth/select-role'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'role': role}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveSession(
          token: data['token'],
          userId: data['user_id'],
          role: data['role'],
        );
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveSession({
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

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('backend_user_id');
  }

  Future<String?> getStoredRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('backend_role');
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('backend_user_id');
    await prefs.remove('backend_role');
  }
  // ===================== AUTHORIZED REQUESTS (auto-refresh) =====================

  Future<Map<String, String>> _authHeaders() async {
    final token = await _firebaseAuth.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Kisi bhi protected GET/POST ko call karta hai. Agar JWT expire ho gaya
  /// (401 aaya), silently Firebase se naya token le ke backend se fresh JWT
  /// leta hai aur request dobara try karta hai — user ko pata bhi nahi chalta.
  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    var headers = await _authHeaders();
    var response = await request(headers);

    if (response.statusCode == 401) {
      final refreshed = await verifyWithBackend();
      if (refreshed != null) {
        headers = await _authHeaders();
        response = await request(headers);
      }
    }
    return response;
  }

  Future<http.Response> authorizedGet(String path) {
    return _authorizedRequest(
      (headers) => http
          .get(Uri.parse('$_apiV1$path'), headers: headers)
          .timeout(_timeout),
    );
  }

  Future<http.Response> authorizedPost(String path, Map<String, dynamic> body) {
    return _authorizedRequest(
      (headers) => http
          .post(
            Uri.parse('$_apiV1$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
  }

  Future<http.Response> authorizedPut(String path, Map<String, dynamic> body) {
    return _authorizedRequest(
      (headers) => http
          .put(
            Uri.parse('$_apiV1$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
  }

  Future<http.Response> authorizedPatch(
    String path,
    Map<String, dynamic> body,
  ) {
    return _authorizedRequest(
      (headers) => http
          .patch(
            Uri.parse('$_apiV1$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    await _clearSession();
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
