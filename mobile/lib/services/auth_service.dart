import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'realtime_service.dart';

/// Holds the session (JWT + current user) and persists it. Widgets listen to
/// it to rebuild when the profile changes or the user logs out.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? token;
  User? user;

  /// Set when the server ends the session (e.g. account suspended) so the
  /// login screen can explain why.
  String? sessionEndedReason;

  bool get loggedIn => token != null && user != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      try {
        user = User.fromJson(jsonDecode(userJson));
      } catch (_) {
        user = null;
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('token');
    } else {
      await prefs.setString('token', token!);
    }
    if (user == null) {
      await prefs.remove('user');
    } else {
      await prefs.setString('user', jsonEncode(user!.toJson()));
    }
  }

  Future<void> _startSession(Map<String, dynamic> body) async {
    token = body['token']?.toString();
    user = User.fromJson(Map<String, dynamic>.from(body['user']));
    sessionEndedReason = null;
    await _save();
    RealtimeService.instance.connect(token!);
    notifyListeners();
  }

  Future<User> login(String email, String password) async {
    final body = await ApiClient.post('/api/auth/login', {'email': email, 'password': password});
    await _startSession(Map<String, dynamic>.from(body));
    return user!;
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? city,
  }) async {
    final body = await ApiClient.post('/api/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (city != null && city.isNotEmpty) 'city': city,
    });
    await _startSession(Map<String, dynamic>.from(body));
    return user!;
  }

  /// Re-fetch the current user after anything that changes it server-side.
  Future<void> refreshUser() async {
    if (token == null) return;
    try {
      final res = await ApiClient.getMap('/api/users/me');
      if (res.isEmpty) return;
      user = User.fromJson(res);
      await _save();
      notifyListeners();
    } catch (_) {
      // Best effort — keep the cached user.
    }
  }

  Future<User> updateProfile(Map<String, dynamic> fields) async {
    final res = await ApiClient.patch('/api/users/me', fields);
    user = User.fromJson(Map<String, dynamic>.from(res));
    await _save();
    notifyListeners();
    return user!;
  }

  Future<User> uploadAvatar(XFile file) async {
    final res = await ApiClient.multipart('/api/users/me/avatar', {}, files: {'avatar': file});
    user = User.fromJson(Map<String, dynamic>.from(res));
    await _save();
    notifyListeners();
    return user!;
  }

  Future<void> changePassword(String current, String next) async {
    await ApiClient.post('/api/auth/change-password', {'currentPassword': current, 'newPassword': next});
  }

  Future<void> logout() async {
    RealtimeService.instance.disconnect();
    token = null;
    user = null;
    await _save();
    notifyListeners();
  }

  /// Called by ApiClient on 401 / suspension.
  void handleUnauthorized([String? reason]) {
    if (!loggedIn) return;
    sessionEndedReason = reason ?? 'Your session expired. Please log in again.';
    logout();
  }
}
