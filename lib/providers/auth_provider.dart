import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages the app's local password lock.
///
/// The password itself lives in a small Hive box ('settings') as a plain
/// string under one key - no new Hive type/adapter is needed since
/// String is natively supported. Nothing about the existing Product,
/// Sale, Supplier, Debt or Note boxes changes, so there is zero risk to
/// existing data.
///
/// This is a simple local app-lock (single shared password), not a
/// multi-user auth system - appropriate for a single-device offline POS.
class AuthProvider extends ChangeNotifier {
  static const String boxName = 'settings';
  static const String _passwordKey = 'app_password';
  static const String defaultPassword = '12345';

  Box<String> get _box => Hive.box<String>(boxName);

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  /// The password currently required to log in. Falls back to
  /// [defaultPassword] the very first time the app runs (before the
  /// merchant ever changes it), and whenever the stored value is
  /// somehow missing or empty.
  String get _currentPassword {
    final stored = _box.get(_passwordKey);
    return (stored == null || stored.isEmpty) ? defaultPassword : stored;
  }

  /// Whether the merchant is still using the factory-default password.
  /// Exposed so the UI can gently nudge them to change it after login.
  bool get isUsingDefaultPassword => _currentPassword == defaultPassword;

  /// Attempts to log in with [enteredPassword]. Returns true and marks
  /// the app unlocked on success; returns false (and leaves the app
  /// locked) on a wrong password.
  bool login(String enteredPassword) {
    if (enteredPassword == _currentPassword) {
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Locks the app again, sending the user back to the login screen.
  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Changes the app password. Requires the correct [oldPassword] first,
  /// so a logged-in session can't be used by someone else to silently
  /// take over the lock. Returns 'ok' on success, or a reason string the
  /// UI can show directly:
  /// - 'wrong_old_password'
  /// - 'empty_new_password'
  /// - 'too_short' (fewer than 4 characters)
  Future<String> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (oldPassword != _currentPassword) {
      return 'wrong_old_password';
    }

    final trimmedNew = newPassword.trim();
    if (trimmedNew.isEmpty) {
      return 'empty_new_password';
    }
    if (trimmedNew.length < 4) {
      return 'too_short';
    }

    await _box.put(_passwordKey, trimmedNew);
    notifyListeners();
    return 'ok';
  }
}