import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Backend URL — platform ke hisab se badalna:
  // Web (Chrome): http://127.0.0.1:8000
  // Android Emulator: http://10.0.2.2:8000
  // Real Phone (same WiFi): http://<PC-KA-LAN-IP>:8000  (backend --host 0.0.0.0 se chalana)
  static const String baseUrl = 'http://192.168.1.9:8000';

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

      final idToken = await user.getIdToken(true); // force refresh

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

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
      final userId = await getStoredUserId();
      if (userId == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/select-role'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'role': role}),
      );

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
    final token = await getStoredToken();
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
          (headers) => http.get(Uri.parse('$baseUrl$path'), headers: headers),
    );
  }

  Future<http.Response> authorizedPost(String path, Map<String, dynamic> body) {
    return _authorizedRequest(
          (headers) => http.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    await _clearSession();
  }
}