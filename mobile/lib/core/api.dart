import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/json.dart';
import 'session.dart';

/// Where the backend lives. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:4000
///
/// The default works for: the website and desktop on the same PC; a real
/// Android phone over USB after `adb reverse tcp:4000 tcp:4000`. On the
/// Android emulator pass API_BASE_URL=http://10.0.2.2:4000.
abstract final class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');
  static String get baseUrl => _override.isNotEmpty ? _override : 'http://localhost:4000';
}

/// Full URL of an uploaded file (absolute URLs pass through unchanged).
String mediaUrl(String file) {
  if (file.isEmpty || file.startsWith('http://') || file.startsWith('https://')) return file;
  return '${ApiConfig.baseUrl}/uploads/$file';
}

class ApiError implements Exception {
  final int status; // 0 = could not reach the server
  final String message;
  final String? code;
  final Json details;
  ApiError(this.status, this.message, {this.code, this.details = const {}});

  bool get isNetwork => status == 0;
  bool get insufficientFunds => code == 'insufficient_funds';

  @override
  String toString() => message;
}

/// JSON-over-HTTP client: adds the session token, a timeout and readable
/// errors, and ends the session when the server rejects the token.
abstract final class Api {
  static const _timeout = Duration(seconds: 20);
  static http.Client client = http.Client();

  static Map<String, String> _headers({bool json = true}) {
    final token = Session.instance.token;
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    final q = <String, String>{...base.queryParameters};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return q.isEmpty ? base : base.replace(queryParameters: q);
  }

  static dynamic _read(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final map = asJson(body);
    final message = str(map['error'], 'Something went wrong (HTTP ${res.statusCode})');
    final code = map['code']?.toString();
    if ((res.statusCode == 401 && Session.instance.token != null) || code == 'suspended') {
      Session.instance.endedByServer(code == 'suspended' ? message : null);
    }
    throw ApiError(res.statusCode, message, code: code, details: asJson(map['details']));
  }

  static Future<dynamic> _send(Future<http.Response> Function() call) async {
    try {
      return _read(await call().timeout(_timeout));
    } on TimeoutException {
      throw ApiError(0, 'The server is taking too long to respond. Please try again.');
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError(0, "Can't reach SureFix. Check your connection and that the backend is running.");
    }
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send(() => client.get(_uri(path, query), headers: _headers()));

  static Future<List<Json>> list(String path, {Map<String, dynamic>? query}) async => asJsonList(await get(path, query: query));

  static Future<Json> map(String path, {Map<String, dynamic>? query}) async => asJson(await get(path, query: query));

  static Future<dynamic> post(String path, [Json? body]) => _send(() => client.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  static Future<dynamic> patch(String path, [Json? body]) => _send(() => client.patch(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  static Future<dynamic> delete(String path) => _send(() => client.delete(_uri(path), headers: _headers()));

  /// multipart/form-data: [fields] plus one or more files per field name.
  static Future<dynamic> upload(String path, {Map<String, String> fields = const {}, Map<String, List<XFile>> files = const {}, String method = 'POST'}) async {
    final req = http.MultipartRequest(method, _uri(path));
    req.headers.addAll(_headers(json: false));
    req.fields.addAll(fields);
    for (final entry in files.entries) {
      for (final file in entry.value) {
        req.files.add(http.MultipartFile.fromBytes(entry.key, await file.readAsBytes(), filename: file.name));
      }
    }
    return _send(() async => http.Response.fromStream(await client.send(req)));
  }
}
