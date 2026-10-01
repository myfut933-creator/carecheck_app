import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../utils/app_exception.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service) {
    _sub = _service.authChanges.listen((u) {
      user = u;
      initialised = true;
      notifyListeners();
    });
  }

  final AuthService _service;
  StreamSubscription<User?>? _sub;

  User? user;
  bool initialised = false;
  bool busy = false;
  String? error;

  Future<bool> signIn(String email, String password) =>
      _run(() => _service.signIn(email, password));

  Future<bool> register(String name, String email, String password) => _run(
      () => _service.register(name: name, email: email, password: password));

  Future<void> signOut() => _service.signOut();

  Future<bool> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppException catch (e) {
      error = e.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
