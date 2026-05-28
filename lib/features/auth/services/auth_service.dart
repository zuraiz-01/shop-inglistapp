import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection {
    return _firestore.collection('users');
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException('Could not create your account.');
      }

      await user.updateDisplayName(name.trim());
      await _createUserDocument(user: user, name: name.trim());

      return UserModel(
        uid: user.uid,
        name: name.trim(),
        email: user.email ?? email.trim(),
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_authErrorMessage(error));
    } on FirebaseException catch (error) {
      await _deleteCurrentUserIfPossible();
      throw AuthServiceException(_firestoreErrorMessage(error));
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      await _deleteCurrentUserIfPossible();
      throw const AuthServiceException(
        'Something went wrong while creating your account.',
      );
    }
  }

  Future<UserModel> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException('Could not sign you in.');
      }

      final appUser = await getCurrentUser();
      if (appUser == null) {
        throw const AuthServiceException('User profile was not found.');
      }

      return appUser;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_authErrorMessage(error));
    } on FirebaseException catch (error) {
      throw AuthServiceException(_firestoreErrorMessage(error));
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong while signing you in.',
      );
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_authErrorMessage(error));
    } catch (_) {
      throw const AuthServiceException('Could not sign you out.');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_authErrorMessage(error));
    } catch (_) {
      throw const AuthServiceException(
        'Could not send the password reset email.',
      );
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      final doc = await _usersCollection.doc(user.uid).get();
      if (!doc.exists) {
        return null;
      }

      return UserModel.fromFirestore(doc);
    } on FirebaseException catch (error) {
      throw AuthServiceException(_firestoreErrorMessage(error));
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException('Could not load your profile.');
    }
  }

  Future<void> _createUserDocument({
    required User user,
    required String name,
  }) async {
    await _usersCollection.doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': user.email,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteCurrentUserIfPossible() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {
      // Best-effort cleanup for failed signup profile creation.
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    final message = error.message ?? '';

    if (message.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Authentication is not configured. Enable Email/Password sign-in in Firebase Console.';
    }

    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email and password sign in is not enabled.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'configuration-not-found':
        return 'Firebase Authentication is not configured. Enable Email/Password sign-in in Firebase Console.';
      default:
        return message.isNotEmpty
            ? message
            : 'Authentication failed. Please try again.';
    }
  }

  String _firestoreErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to access this data.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again.';
      case 'not-found':
        return 'The requested profile was not found.';
      default:
        return error.message ?? 'Database request failed. Please try again.';
    }
  }
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
