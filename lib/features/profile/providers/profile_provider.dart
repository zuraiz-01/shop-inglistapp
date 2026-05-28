import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> updateDisplayName({
    required String uid,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _setError('Display name is required.');
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      await _firestore.collection('users').doc(uid).update({
        'name': trimmedName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firebaseAuth.currentUser?.updateDisplayName(trimmedName);
      return true;
    } on FirebaseException catch (error) {
      _errorMessage = _firestoreErrorMessage(error);
      return false;
    } catch (_) {
      _errorMessage = 'Could not update your profile.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    _safeNotifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    _safeNotifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _safeNotifyListeners();
  }

  String _firestoreErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to update this profile.';
      case 'not-found':
        return 'Your profile was not found.';
      case 'unavailable':
        return 'Cloud Firestore is unavailable. Check your connection.';
      default:
        return error.message ?? 'Could not update your profile.';
    }
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
