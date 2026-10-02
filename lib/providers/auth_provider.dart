import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Who is using the app in this session.
enum UserRole {
  /// Full access to every page, figure and setting.
  admin,

  /// Restricted mode: POS + calculator, debt repayments (without totals
  /// or the full debtor list), and only the sales log in Inventory.
  employee,
}

extension UserRoleLabel on UserRole {
  String get label => this == UserRole.admin ? 'المدير' : 'الموظف';
}

/// Manages the app lock and the two login roles (Admin / Employee).
///
/// Passwords live in the small 'settings' Hive box as plain strings, so
/// no Hive TypeAdapter is needed and no other box is touched.
///
/// The Admin password keeps the ORIGINAL key ('app_password'), so a shop
/// that already changed its password keeps it after this update. The
/// Employee password uses a new key. Both default to '12345'.
///
/// This is a simple local app-lock for a single shared POS device, not a
/// networked multi-user auth system.
class AuthProvider extends ChangeNotifier {
  static const String boxName = 'settings';
  static const String _adminPasswordKey = 'app_password';
  static const String _employeePasswordKey = 'employee_password';
  static const String defaultPassword = '12345';

  Box<String> get _box => Hive.box<String>(boxName);

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  UserRole? _role;

  /// The logged-in role, or null while locked.
  UserRole? get role => _isAuthenticated ? _role : null;

  bool get isAdmin => _isAuthenticated && _role == UserRole.admin;
  bool get isEmployee => _isAuthenticated && _role == UserRole.employee;

  String _passwordFor(UserRole role) {
    final key = role == UserRole.admin ? _adminPasswordKey : _employeePasswordKey;
    final stored = _box.get(key);
    return (stored == null || stored.isEmpty) ? defaultPassword : stored;
  }

  /// Whether the Admin is still using the factory-default password.
  bool get isUsingDefaultPassword => _passwordFor(UserRole.admin) == defaultPassword;

  /// Whether the Employee is still using the factory-default password.
  bool get isEmployeeUsingDefaultPassword =>
      _passwordFor(UserRole.employee) == defaultPassword;

  /// Attempts to log in as [role]. Returns true and unlocks the app on
  /// success; returns false (and stays locked) on a wrong password.
  bool login(UserRole role, String enteredPassword) {
    if (enteredPassword == _passwordFor(role)) {
      _role = role;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Locks the app again, sending the user back to the login screen.
  void logout() {
    _isAuthenticated = false;
    _role = null;
    notifyListeners();
  }

  /// Validates a new password. Returns null when fine, else a reason:
  /// 'empty_new_password' / 'too_short' (fewer than 4 characters).
  String? _validateNew(String newPassword) {
    final trimmed = newPassword.trim();
    if (trimmed.isEmpty) return 'empty_new_password';
    if (trimmed.length < 4) return 'too_short';
    return null;
  }

  /// Changes the ADMIN password. Admin only, and requires the current
  /// admin password. Returns 'ok', 'not_allowed', 'wrong_old_password',
  /// 'empty_new_password' or 'too_short'.
  Future<String> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!isAdmin) return 'not_allowed';
    if (oldPassword != _passwordFor(UserRole.admin)) return 'wrong_old_password';
    final invalid = _validateNew(newPassword);
    if (invalid != null) return invalid;

    await _box.put(_adminPasswordKey, newPassword.trim());
    notifyListeners();
    return 'ok';
  }

  /// Sets the EMPLOYEE password. Admin only; the admin confirms with
  /// their own current password (the old employee password is not
  /// needed, so a forgotten one can always be reset). Same return codes
  /// as [changePassword].
  Future<String> setEmployeePassword({
    required String adminPassword,
    required String newPassword,
  }) async {
    if (!isAdmin) return 'not_allowed';
    if (adminPassword != _passwordFor(UserRole.admin)) return 'wrong_old_password';
    final invalid = _validateNew(newPassword);
    if (invalid != null) return invalid;

    await _box.put(_employeePasswordKey, newPassword.trim());
    notifyListeners();
    return 'ok';
  }
}
