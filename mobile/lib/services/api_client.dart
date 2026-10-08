import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  final String? code;
  ApiException(this.status, this.message, {this.code});

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

/// Thin JSON-over-HTTP client. Adds the bearer token, a timeout, readable
/// errors, and logs the user out when the server says the token is dead.
class ApiClient {
  static const _timeout = Duration(seconds: 20);
  static http.Client httpClient = http.Client();

  static Map<String, String> _headers({bool json = true}) {
    final token = AuthService.instance.token;
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    final q = {...base.queryParameters, ...?query}..removeWhere((_, v) => v.isEmpty);
    return q.isEmpty ? base : base.replace(queryParameters: q);
  }

  static dynamic _handle(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final msg = body is Map && body['error'] != null ? body['error'].toString() : 'Something went wrong (HTTP ${res.statusCode})';
    final code = body is Map ? body['code']?.toString() : null;
    if (res.statusCode == 401 || code == 'suspended') {
      // Token expired/invalid or account suspended: drop the session.
      AuthService.instance.handleUnauthorized(code == 'suspended' ? msg : null);
    }
    throw ApiException(res.statusCode, msg, code: code);
  }

  static Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(0, 'The server is taking too long to respond. Please try again.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, "Can't reach SureFix. Check your connection and that the backend is running.");
    }
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final res = await _send(() => httpClient.get(uri(path, query), headers: _headers()));
    return _handle(res);
  }

  /// GET a list endpoint; tolerates non-list responses.
  static Future<List<Map<String, dynamic>>> getList(String path, {Map<String, String>? query}) async {
    final res = await get(path, query: query);
    if (res is! List) return [];
    return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> getMap(String path, {Map<String, String>? query}) async {
    final res = await get(path, query: query);
    return res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
  }

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await _send(() => httpClient.post(uri(path), headers: _headers(), body: jsonEncode(body ?? {})));
    return _handle(res);
  }

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await _send(() => httpClient.patch(uri(path), headers: _headers(), body: jsonEncode(body ?? {})));
    return _handle(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await _send(() => httpClient.delete(uri(path), headers: _headers()));
    return _handle(res);
  }

  /// Sends fields + images as multipart/form-data.
  /// [files]: one file per field (e.g. 'idFront'); [multiFiles]: several
  /// files under one field name (e.g. 'images'), matching multer's
  /// `upload.array(...)`. Uses XFile.readAsBytes() so it works on web too.
  static Future<dynamic> multipart(
    String path,
    Map<String, String> fields, {
    String method = 'POST',
    Map<String, XFile?> files = const {},
    Map<String, List<XFile>> multiFiles = const {},
  }) async {
    final req = http.MultipartRequest(method, uri(path));
    req.headers.addAll(_headers(json: false));
    req.fields.addAll(fields);
    Future<void> add(String field, XFile file) async {
      req.files.add(http.MultipartFile.fromBytes(field, await file.readAsBytes(), filename: file.name));
    }

    for (final e in files.entries) {
      if (e.value != null) await add(e.key, e.value!);
    }
    for (final e in multiFiles.entries) {
      for (final f in e.value) {
        await add(e.key, f);
      }
    }
    final res = await _send(() async => http.Response.fromStream(await httpClient.send(req)));
    return _handle(res);
  }

  /// Backwards-compatible name used by older screens.
  static Future<dynamic> postMultipart(
    String path,
    Map<String, String> fields, {
    Map<String, XFile?> files = const {},
    Map<String, List<XFile>> multiFiles = const {},
  }) =>
      multipart(path, fields, files: files, multiFiles: multiFiles);
}
