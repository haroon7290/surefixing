import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_config.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => 'ApiException($status): $message';
}

class ApiClient {
  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = AuthService.instance.token;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: {...base.queryParameters, ...query});
  }

  static dynamic _handle(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'HTTP ${res.statusCode}';
    throw ApiException(res.statusCode, msg);
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    return _handle(res);
  }

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http.delete(_uri(path), headers: await _headers());
    return _handle(res);
  }

  /// Sends fields + optional images as multipart/form-data.
  /// [files]: one file per named field (e.g. 'idFront' -> single XFile).
  /// [multiFiles]: several files under the SAME field name (e.g. 'images'
  /// -> up to 5 XFiles), matching a backend multer `upload.array(...)`.
  /// Uses XFile.readAsBytes() throughout so this works identically on web
  /// and on real devices -- no dart:io File needed.
  static Future<dynamic> postMultipart(
    String path,
    Map<String, String> fields, {
    Map<String, XFile?> files = const {},
    Map<String, List<XFile>> multiFiles = const {},
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    final headers = await _headers(json: false);
    req.headers.addAll(headers);
    req.fields.addAll(fields);
    for (final entry in files.entries) {
      final file = entry.value;
      if (file == null) continue;
      final bytes = await file.readAsBytes();
      req.files.add(http.MultipartFile.fromBytes(
        entry.key,
        bytes,
        filename: file.name,
      ));
    }
    for (final entry in multiFiles.entries) {
      for (final file in entry.value) {
        final bytes = await file.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes(
          entry.key,
          bytes,
          filename: file.name,
        ));
      }
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }
}