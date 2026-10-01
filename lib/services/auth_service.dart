import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_exception.dart';

/// Wraps Firebase Authentication and the users/{uid} profile document.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw AppException('Could not create the account. Please try again.');
      }
      await user.updateDisplayName(name.trim());
      await _db.collection('users').doc(user.uid).set({
        'displayName': name.trim(),
        'email': email.trim(),
        'role': 'support_worker',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e));
    } on FirebaseException catch (e) {
      throw AppException('Your account was created but the profile could not be '
          'saved (${e.code}). Please sign in again.');
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a stronger password (6+ characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your connection and try again.';
      default:
        return 'Something went wrong (${e.code}). Please try again.';
    }
  }
}
