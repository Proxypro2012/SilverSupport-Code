import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> registerUser({
    required String email,
    required String password,
    required String name,
    required String role, // "senior" or "student"
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = result.user!.uid;

    // Add user to Firestore
    await _firestore
        .collection(role == "senior" ? "seniors" : "students")
        .doc(uid)
        .set({"uid": uid, "name": name, "email": email});

    // Send verification email
    await result.user!.sendEmailVerification();
  }

  Future<bool> loginUser(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (!result.user!.emailVerified) {
      await _auth.signOut();
      return false; // Not verified
    }

    return true; // Verified
  }

  Future<void> signOut() async => await _auth.signOut();

  User? getCurrentUser() => _auth.currentUser; // ✅ added
}
