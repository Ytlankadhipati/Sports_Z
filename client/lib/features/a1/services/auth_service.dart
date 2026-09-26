import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current logged-in user
  User? get currentUser => _firebaseAuth.currentUser;

  // Check if current user's email is verified (fresh check from server)
  Future<bool> isEmailVerified() async {
    User? user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload(); // latest status server se le aao
    user = _firebaseAuth.currentUser;
    return user?.emailVerified ?? false;
  }

  // Check if user signed in via Google (Google emails are always pre-verified)
  bool isGoogleUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  // LOGIN — returns null on success, error message on failure
  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // success
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

  // SIGNUP — returns null on success, error message on failure
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Signup ke turant baad verification email bhejo
      await credential.user?.sendEmailVerification();
      return null; // success
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
  // PHONE AUTH — Step 1: OTP bhejo
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
        // Android pe kabhi-kabhi auto-verify ho jata hai
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

  // PHONE AUTH — Step 2: OTP verify karo
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
      return null; // success
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

  // Verification email dobara bhejna (Resend button ke liye)
  Future<String?> resendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        return null; // success
      }
      return 'No user found';
    } catch (e) {
      return 'Failed to send email: $e';
    }
  }

  // GOOGLE SIGN-IN
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return 'Sign in cancelled';
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      return null; // success
    } catch (e) {
      return 'Google sign-in failed: $e';
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}