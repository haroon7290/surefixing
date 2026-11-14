/// Lenient JSON readers: the API is typed, but a missing or oddly-typed
/// field should never crash a screen.
typedef Json = Map<String, dynamic>;

Json asJson(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Json> asJsonList(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Json>[];

String str(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

double dbl(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

int integer(dynamic v, [int fallback = 0]) => v is num ? v.round() : int.tryParse('$v') ?? fallback;

bool boolean(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;

DateTime? date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

List<String> strings(dynamic v) => v is List ? v.where((e) => e != null).map((e) => e.toString()).toList() : <String>[];

/// The id of a document or of a reference to one (populated object or bare id).
String idOf(dynamic v) {
  if (v == null) return '';
  if (v is Map) return str(v['_id'] ?? v['id']);
  return v.toString();
}

/// A latitude/longitude pair (the server sends `{lat, lng}`).
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);

  static GeoPoint? tryParse(dynamic v) {
    if (v is! Map) return null;
    final lat = v['lat'], lng = v['lng'];
    if (lat is! num || lng is! num) return null;
    return GeoPoint(lat.toDouble(), lng.toDouble());
  }

  Json toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}
