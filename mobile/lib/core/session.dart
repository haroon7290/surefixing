import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/json.dart';
import '../models/user.dart';
import 'api.dart';
import 'realtime.dart';

/// The signed-in account (JWT + user), saved on the device. Widgets listen
/// to it to rebuild when the profile changes or the user signs out.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  String? token;
  User? user;

  /// Why the server ended the last session (e.g. account suspended), shown
  /// once on the sign-in screen.
  String? endedReason;

  bool get loggedIn => token != null && user != null;
  String get role => user?.role ?? 'client';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    final saved = prefs.getString('user');
    if (saved != null) {
      try {
        user = User.fromJson(asJson(jsonDecode(saved)));
      } catch (_) {
        user = null;
      }
    }
    if (user == null) token = null;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || user == null) {
      await prefs.remove('token');
      await prefs.remove('user');
    } else {
      await prefs.setString('token', token!);
      await prefs.setString('user', jsonEncode(user!.toJson()));
    }
  }

  Future<void> _start(dynamic body) async {
    final json = asJson(body);
    token = json['token']?.toString();
    user = User.fromJson(asJson(json['user']));
    endedReason = null;
    await _save();
    Realtime.instance.connect(token!);
    notifyListeners();
  }

  Future<void> _setUser(dynamic body) async {
    user = User.fromJson(asJson(body));
    await _save();
    notifyListeners();
  }

  Future<void> login(String email, String password) async =>
      _start(await Api.post('/api/auth/login', {'email': email.trim(), 'password': password}));

  Future<void> register({required String name, required String email, required String password, required String role, String phone = '', String city = ''}) async =>
      _start(await Api.post('/api/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (city.trim().isNotEmpty) 'city': city.trim(),
      }));

  /// Asks for a reset code. Returns the server's answer; outside production
  /// without an email server it includes `devCode`.
  Future<Json> forgotPassword(String email) async => asJson(await Api.post('/api/auth/forgot-password', {'email': email.trim()}));

  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    final body = asJson(await Api.post('/api/auth/reset-password', {'email': email.trim(), 'code': code.trim(), 'newPassword': newPassword}));
    if (body['token'] != null) await _start(body);
  }

  Future<void> changePassword(String current, String next) => Api.post('/api/auth/change-password', {'currentPassword': current, 'newPassword': next});

  /// Re-reads the account after anything that changes it server-side
  /// (wallet movements, verification, ratings).
  Future<void> refresh() async {
    if (token == null) return;
    try {
      final res = await Api.map('/api/users/me');
      if (res.isNotEmpty) await _setUser(res);
    } catch (_) {
      // Best effort: keep the cached account.
    }
  }

  Future<void> updateProfile(Json fields) async => _setUser(await Api.patch('/api/users/me', fields));

  Future<void> uploadAvatar(XFile file) async => _setUser(await Api.upload('/api/users/me/avatar', files: {'avatar': [file]}));

  Future<void> addPortfolio(List<XFile> files) async => _setUser(await Api.upload('/api/users/me/portfolio', files: {'images': files}));

  Future<void> removePortfolio(String file) async => _setUser(await Api.delete('/api/users/me/portfolio/$file'));

  // ---------------------------------------------------------- favourites

  bool isFavorite(String type, String id) => (type == 'tool' ? user?.favoriteTools : user?.favoriteTechnicians)?.contains(id) ?? false;

  /// Saves or un-saves a technician or tool; returns the new state.
  Future<bool> toggleFavorite(String type, String id) async {
    final res = asJson(await Api.post('/api/users/me/favorites', {'type': type, 'id': id}));
    final saved = res['saved'] == true;
    final u = user;
    if (u != null) {
      List<String> next(List<String> list) => saved ? {...list, id}.toList() : list.where((x) => x != id).toList();
      user = User.fromJson({
        ...u.toJson(),
        if (type == 'tool') 'favoriteTools': next(u.favoriteTools) else 'favoriteTechnicians': next(u.favoriteTechnicians),
      });
      await _save();
      notifyListeners();
    }
    return saved;
  }

  /// Local wallet balance update pushed by the server after a movement.
  void setBalance(double balance) {
    final u = user;
    if (u == null || u.walletBalance == balance) return;
    user = User.fromJson({...u.toJson(), 'walletBalance': balance});
    _save();
    notifyListeners();
  }

  Future<void> logout() async {
    Realtime.instance.disconnect();
    token = null;
    user = null;
    await _save();
    notifyListeners();
  }

  /// Called by the API client on 401 / suspension.
  void endedByServer([String? reason]) {
    if (!loggedIn) return;
    endedReason = reason ?? 'Your session expired. Please sign in again.';
    logout();
  }
}

/// Device-local preferences: theme mode and whether the intro was seen.
class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  ThemeMode themeMode = ThemeMode.system;
  bool introSeen = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values.firstWhere((m) => m.name == prefs.getString('themeMode'), orElse: () => ThemeMode.system);
    introSeen = prefs.getBool('introSeen') ?? false;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> finishIntro() async {
    introSeen = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('introSeen', true);
  }
}
