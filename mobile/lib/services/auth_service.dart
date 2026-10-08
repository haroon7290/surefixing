import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_config.dart';
import 'realtime_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? token;
  User? user;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) user = User.fromJson(jsonDecode(userJson));
  }

  // Re-fetch the current user from the server. Call after any action that
  // mutates server-side user state (profile edit, KYC submit, KYC verdict)
  // so the drawer / profile show fresh values without needing a re-login.
  Future<void> refreshUser() async {
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return;
      user = User.fromJson(jsonDecode(res.body));
      await _save();
    } catch (_) {
      // Best effort — silent failure leaves the cached user in place.
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

  Future<User> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(body['error'] ?? 'Login failed');
    token = body['token'];
    user = User.fromJson(body['user']);
    await _save();
    RealtimeService.instance.connect(token!);
    return user!;
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (phone != null) 'phone': phone,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode >= 300) throw Exception(body['error'] ?? 'Register failed');
    token = body['token'];
    user = User.fromJson(body['user']);
    await _save();
    RealtimeService.instance.connect(token!);
    return user!;
  }

  Future<void> logout() async {
    RealtimeService.instance.disconnect();
    token = null;
    user = null;
    await _save();
  }

  bool get loggedIn => token != null && user != null;
}
