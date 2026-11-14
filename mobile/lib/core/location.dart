import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/json.dart';
import 'api.dart';
import 'session.dart';

/// A neighbourhood from the server's list (GET /api/meta/areas).
class Area {
  final String city;
  final String name;
  final GeoPoint point;
  const Area(this.city, this.name, this.point);

  String get label => '$name, $city';

  factory Area.fromJson(Json j) => Area(str(j['city']), str(j['name']), GeoPoint(dbl(j['lat']), dbl(j['lng'])));
}

/// A spot on the map plus how to describe it ("DHA Phase 5, Lahore").
class Place {
  final GeoPoint point;
  final String area;
  final String city;

  /// gps | area | map | profile — only changes the wording.
  final String source;
  const Place({required this.point, this.area = '', this.city = '', this.source = 'map'});

  /// Short name for chips: the neighbourhood when known.
  String get label {
    if (area.isNotEmpty) return area;
    if (source == 'gps') return 'Your location';
    if (city.isNotEmpty) return city;
    return 'Pinned spot';
  }

  /// "DHA Phase 5, Lahore".
  String get fullLabel => [label, if (city.isNotEmpty && city != label) city].join(', ');

  Json toJson() => {...point.toJson(), 'area': area, 'city': city, 'source': source};

  static Place? fromJson(dynamic v) {
    final p = GeoPoint.tryParse(v);
    if (p == null) return null;
    final j = asJson(v);
    return Place(point: p, area: str(j['area']), city: str(j['city']), source: str(j['source'], 'map'));
  }
}

/// Why the device position could not be read, in words for the user.
class LocationError implements Exception {
  final String message;

  /// True when only the system settings can fix it (permission blocked).
  final bool needsSettings;
  const LocationError(this.message, {this.needsSettings = false});

  @override
  String toString() => message;
}

/// Great-circle distance in km.
double kmBetween(GeoPoint a, GeoPoint b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// Search distances offered in the filters (0 = any distance).
const searchRadii = [0, 2, 5, 10, 25, 50];

/// Where "near me" searches start from and how far they reach. Shared by
/// the technician directory, the tool market and the job market, and
/// remembered on the device.
///
/// The place is the one picked on this device (GPS, an area or a map pin);
/// without one, the signed-in user's saved location is used.
class Locations extends ChangeNotifier {
  Locations._() {
    Session.instance.addListener(notifyListeners);
  }
  static final Locations instance = Locations._();

  Place? _chosen;
  int radiusKm = 0;
  List<Area> _areas = const [];
  Future<List<Area>>? _loading;

  /// The place picked on this device, if any.
  Place? get chosen => _chosen;

  /// Where searches start from, or null when nothing is known yet.
  Place? get searchFrom {
    if (_chosen != null) return _chosen;
    final u = Session.instance.user;
    if (u?.geo == null) return null;
    return Place(point: u!.geo!, area: u.area, city: u.city, source: 'profile');
  }

  bool get known => searchFrom != null;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('searchPlace');
      _chosen = saved == null ? null : Place.fromJson(jsonDecode(saved));
      radiusKm = prefs.getInt('searchRadius') ?? 0;
      if (!searchRadii.contains(radiusKm)) radiusKm = 0;
    } catch (_) {
      _chosen = null;
    }
  }

  /// Search from [place]; null goes back to the saved profile location.
  Future<void> choose(Place? place) async {
    _chosen = place;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (place == null) {
      await prefs.remove('searchPlace');
    } else {
      await prefs.setString('searchPlace', jsonEncode(place.toJson()));
    }
  }

  Future<void> setRadius(int km) async {
    if (km == radiusKm) return;
    radiusKm = km;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('searchRadius', km);
  }

  /// `lat`, `lng` and `radius` for an API query (empty without a place).
  Map<String, dynamic> query({bool withRadius = true}) {
    final from = searchFrom;
    if (from == null) return const {};
    return {
      'lat': from.point.lat.toStringAsFixed(5),
      'lng': from.point.lng.toStringAsFixed(5),
      if (withRadius && radiusKm > 0) 'radius': radiusKm,
    };
  }

  // ------------------------------------------------------------- areas

  List<Area> get areas => _areas;

  /// The neighbourhood list, fetched once.
  Future<List<Area>> loadAreas() {
    if (_areas.isNotEmpty) return Future.value(_areas);
    return _loading ??= Api.list('/api/meta/areas').then((rows) {
      _areas = rows.map(Area.fromJson).where((a) => a.name.isNotEmpty).toList();
      return _areas;
    }).catchError((Object e) {
      _loading = null;
      throw e;
    });
  }

  Area? _nearest(GeoPoint p, double maxKm) {
    Area? best;
    var bestKm = maxKm;
    for (final a in _areas) {
      final km = kmBetween(p, a.point);
      if (km <= bestKm) {
        best = a;
        bestKm = km;
      }
    }
    return best;
  }

  /// Names a point after the closest neighbourhood (within a few km) and
  /// city (within 40 km).
  Future<Place> describe(GeoPoint p, {String source = 'map'}) async {
    try {
      await loadAreas();
    } catch (_) {
      // Unnamed is fine.
    }
    final area = _nearest(p, 4);
    final city = area ?? _nearest(p, 40);
    return Place(point: p, area: area?.name ?? '', city: city?.city ?? '', source: source);
  }

  // ----------------------------------------------------------- device

  /// Reads the device position, asking for permission the first time.
  Future<GeoPoint> currentPosition() async {
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        throw const LocationError('Location is turned off on this device. Turn it on, or choose your area from the list.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationError('SureFix was not allowed to use your location. Choose your area from the list instead.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationError('Location access is blocked for SureFix. Allow it in your settings, or choose your area from the list.', needsSettings: true);
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)));
      return GeoPoint(pos.latitude, pos.longitude);
    } on LocationError {
      rethrow;
    } on TimeoutException {
      throw const LocationError("Couldn't get a fix on your position. Try again outdoors, or choose your area from the list.");
    } on PermissionDeniedException {
      throw const LocationError('SureFix was not allowed to use your location. Choose your area from the list instead.');
    } catch (e) {
      debugPrint('Location unavailable: $e');
      throw const LocationError("Couldn't read your location on this device. Choose your area from the list instead.");
    }
  }

  /// Opens the system settings page for SureFix (after a blocked permission).
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      // Not available on this platform.
    }
  }

  @visibleForTesting
  void reset() {
    _chosen = null;
    radiusKm = 0;
    _areas = const [];
    _loading = null;
  }
}
