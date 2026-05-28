import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService() {
    _authSubscription = _authService!.authStateChanges.listen(
      _handleAuthStateChanged,
      onError: (_) {
        _setError('Authentication state could not be loaded.');
      },
    );
  }

  AuthProvider.test({
    UserModel? currentUser,
    bool isLoading = false,
    bool hasCheckedAuthState = false,
    String? errorMessage,
  }) : _authService = null {
    _currentUser = currentUser;
    _isLoading = isLoading;
    _hasCheckedAuthState = hasCheckedAuthState;
    _errorMessage = errorMessage;
  }

  final AuthService? _authService;

  StreamSubscription<firebase_auth.User?>? _authSubscription;
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _hasCheckedAuthState = false;
  String? _errorMessage;
  bool _isDisposed = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get hasCheckedAuthState => _hasCheckedAuthState;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  Future<void> signUp(String name, String email, String password) async {
    await _runAuthAction(() async {
      _currentUser = await _authService!.signUpWithEmailAndPassword(
        name: name,
        email: email,
        password: password,
      );
    });
  }

  Future<void> login(String email, String password) async {
    await _runAuthAction(() async {
      _currentUser = await _authService!.loginWithEmailAndPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> logout() async {
    await _runAuthAction(() async {
      await _authService!.logout();
      _currentUser = null;
    });
  }

  void updateCurrentUserName(String name) {
    final user = _currentUser;
    if (user == null) {
      return;
    }

    _currentUser = user.copyWith(name: name);
    _safeNotifyListeners();
  }

  Future<void> resetPassword(String email) async {
    await _runAuthAction(() async {
      await _authService!.resetPassword(email);
    });
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    _safeNotifyListeners();
  }

  Future<void> _handleAuthStateChanged(firebase_auth.User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _hasCheckedAuthState = true;
      _safeNotifyListeners();
      return;
    }

    _setLoading(true);

    try {
      _currentUser = await _authService!.getCurrentUser();
      _errorMessage = null;
    } on AuthServiceException catch (error) {
      _currentUser = null;
      _errorMessage = error.message;
    } catch (_) {
      _currentUser = null;
      _errorMessage = 'Could not load your profile.';
    } finally {
      _hasCheckedAuthState = true;
      _setLoading(false);
    }
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await action();
    } on AuthServiceException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    } finally {
      _setLoading(false);
    }
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

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
