import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../kit.dart';

/// Lahore city centre: where the map opens when nothing better is known.
const _fallbackCentre = GeoPoint(31.5204, 74.3587);

/// Asks where: the device's GPS position, a pin on the map, or a
/// neighbourhood from the list. Returns null when dismissed.
///
/// With [offerSaved] the user's saved profile location is offered too; the
/// result then has `source == 'profile'`.
Future<Place?> pickPlace(BuildContext context, {String title = 'Choose a location', String? subtitle, Place? current, bool offerSaved = false}) =>
    showAppSheet<Place>(context, title: title, subtitle: subtitle, builder: (_) => _PlacePicker(current: current, offerSaved: offerSaved));

/// Changes where "near me" searches start from.
Future<void> pickSearchPlace(BuildContext context) async {
  final loc = Locations.instance;
  final place = await pickPlace(
    context,
    title: 'Search near',
    subtitle: 'Results show how far away each one is, nearest first.',
    current: loc.searchFrom,
    offerSaved: Session.instance.user?.geo != null,
  );
  if (place == null) return;
  await loc.choose(place.source == 'profile' ? null : place);
}

class _PlacePicker extends StatefulWidget {
  final Place? current;
  final bool offerSaved;
  const _PlacePicker({this.current, this.offerSaved = false});

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  late final Future<List<Area>> _areas = Locations.instance.loadAreas();
  bool _locating = false;
  LocationError? _error;
  String _filter = '';

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final point = await Locations.instance.currentPosition();
      final place = await Locations.instance.describe(point, source: 'gps');
      if (mounted) Navigator.of(context).pop(place);
    } on LocationError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _useMap() async {
    final place = await push<Place>(context, MapPickerPage(initial: widget.current));
    if (place != null && mounted) Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = Session.instance.user;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      MenuGroup(children: [
        MenuRow(
          icon: AppIcons.gps,
          tone: Tone.brand,
          title: _locating ? 'Finding you…' : 'Use my current location',
          subtitle: 'The most accurate. Your exact position is never shown to anyone.',
          trailing: _locating ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
          onTap: _locating ? null : _useGps,
        ),
        MenuRow(icon: AppIcons.map, title: 'Pick on the map', subtitle: 'Drag the map to put the pin on the spot.', onTap: _useMap),
        if (widget.offerSaved && user?.geo != null)
          MenuRow(
            icon: AppIcons.pin,
            title: 'My saved location',
            subtitle: user!.place.isEmpty ? 'From your profile' : user.place,
            onTap: () => Navigator.of(context).pop(Place(point: user.geo!, area: user.area, city: user.city, source: 'profile')),
          ),
      ]),
      if (_error != null) ...[
        Gap.h12,
        Notice(
          _error!.message,
          tone: Tone.warning,
          action: _error!.needsSettings ? Btn('Open settings', size: BtnSize.sm, kind: BtnKind.outline, onPressed: Locations.instance.openSettings) : null,
        ),
      ],
      Gap.h24,
      Text('Or choose your area', style: context.text.titleMedium),
      Gap.h12,
      SearchBox(hint: 'Search areas: "DHA", "Gulberg", "F-7"…', onChanged: (v) => setState(() => _filter = v.trim().toLowerCase())),
      Gap.h16,
      FutureBuilder<List<Area>>(
        future: _areas,
        builder: (context, snap) {
          if (snap.hasError) return Text("Couldn't load the list of areas. Use your location or the map instead.", style: context.text.bodyMedium);
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          final areas = snap.data!.where((a) => _filter.isEmpty || a.name.toLowerCase().contains(_filter) || a.city.toLowerCase().contains(_filter)).toList();
          if (areas.isEmpty) return Text('No area called "$_filter". Try the map instead.', style: context.text.bodyMedium);
          // The user's own city first, then the rest in the server's order.
          final home = (widget.current?.city.isNotEmpty ?? false) ? widget.current!.city : (user?.city ?? '');
          final cities = <String>[
            if (areas.any((a) => a.city == home)) home,
            ...{for (final a in areas) a.city}.where((city) => city != home),
          ];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final city in cities) ...[
              Text(city, style: context.text.labelSmall!.copyWith(color: c.muted, fontWeight: FontWeight.w800)),
              Gap.h8,
              Pills<Area>(
                values: areas.where((a) => a.city == city).toList(),
                label: (a) => a.name,
                selected: areas.where((a) => a.city == city && a.name == widget.current?.area && widget.current?.source != 'gps').firstOrNull,
                onTap: (a) => Navigator.of(context).pop(Place(point: a.point, area: a.name, city: a.city, source: 'area')),
              ),
              Gap.h16,
            ],
          ]);
        },
      ),
    ]);
  }
}

/// Full-screen map with a fixed pin in the middle: drag the map under it.
class MapPickerPage extends StatefulWidget {
  final Place? initial;
  final String title;
  const MapPickerPage({super.key, this.initial, this.title = 'Pick on the map'});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final _map = MapController();
  late GeoPoint _centre = widget.initial?.point ?? Locations.instance.searchFrom?.point ?? _fallbackCentre;
  Place? _place;
  Timer? _debounce;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _describe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  Future<void> _describe() async {
    final at = _centre;
    final place = await Locations.instance.describe(at);
    if (mounted && at == _centre) setState(() => _place = place);
  }

  void _moved(MapCamera camera, bool _) {
    _centre = GeoPoint(camera.center.latitude, camera.center.longitude);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _describe);
  }

  Future<void> _gps() async {
    setState(() => _locating = true);
    try {
      final p = await Locations.instance.currentPosition();
      _map.move(LatLng(p.lat, p.lng), 16);
      _centre = p;
      await _describe();
    } on LocationError catch (e) {
      toast(e.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final place = _place;
    return AppPage(
      title: widget.title,
      maxWidth: 1400,
      body: Stack(children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: LatLng(_centre.lat, _centre.lng),
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 18,
              backgroundColor: c.sunken,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onPositionChanged: _moved,
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.surefix.app', maxZoom: 19),
              const SimpleAttributionWidget(source: Text('OpenStreetMap contributors'), alignment: Alignment.topLeft),
            ],
          ),
        ),
        // The pin's tip marks the centre of the map.
        IgnorePointer(
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Icon(AppIcons.pinFill, size: 46, color: c.brand, shadows: const [Shadow(blurRadius: 8, color: Colors.black38, offset: Offset(0, 2))]),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: RoundBtn(AppIcons.gps, tooltip: 'Go to my location', background: c.surface, onPressed: _locating ? null : _gps),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Panel(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const IconTile(AppIcons.pin, tone: Tone.brand, size: 40),
                    Gap.w12,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(place == null ? 'Finding the area…' : (place.area.isEmpty ? 'Unnamed spot' : place.area), style: context.text.titleMedium),
                        Gap.h2,
                        Text(place == null || place.city.isEmpty ? 'Drag the map to move the pin' : '${place.city} · drag the map to move the pin', style: context.text.bodySmall),
                      ]),
                    ),
                  ]),
                  Gap.h12,
                  Btn('Use this spot', icon: AppIcons.check, expand: true, onPressed: place == null ? null : () => Navigator.of(context).pop(place)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The location capsule in a filter row: "Near DHA Phase 5 · 10 km".
class LocationChip extends StatelessWidget {
  const LocationChip({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Locations.instance,
        builder: (context, _) {
          final loc = Locations.instance;
          final from = loc.searchFrom;
          final label = from == null ? 'Set your location' : 'Near ${from.label}${loc.radiusKm > 0 ? ' · ${loc.radiusKm} km' : ''}';
          return BarButton(label, icon: from == null ? AppIcons.gps : AppIcons.pinFill, trailing: AppIcons.chevronDown, on: from != null, onTap: () => pickSearchPlace(context));
        },
      );
}

/// The "Distance" group of a filter panel: where from and how far.
class DistanceFilter extends StatelessWidget {
  /// The radius being edited (a filter sheet keeps its own copy).
  final int radius;
  final ValueChanged<int> onRadius;
  const DistanceFilter({super.key, required this.radius, required this.onRadius});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Locations.instance,
        builder: (context, _) {
          final c = context.colors;
          final from = Locations.instance.searchFrom;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Material(
              color: from == null ? c.brandSoft : c.sunken,
              borderRadius: BorderRadius.circular(R.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => pickSearchPlace(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Icon(from == null ? AppIcons.gps : AppIcons.pinFill, size: 18, color: from == null ? c.brandDeep : c.brand),
                    Gap.w8,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(from == null ? 'Set your location' : from.fullLabel,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall!.copyWith(fontSize: 14, color: from == null ? c.brandDeep : c.ink)),
                        Text(from == null ? 'to see distances and search near you' : (from.source == 'profile' ? 'Saved in your profile · change' : 'Tap to change'),
                            style: context.text.bodySmall),
                      ]),
                    ),
                    Icon(AppIcons.chevronRight, size: 14, color: c.muted),
                  ]),
                ),
              ),
            ),
            Gap.h12,
            Pills<int>(
              values: searchRadii,
              label: (km) => km == 0 ? 'Any distance' : 'Within $km km',
              selected: radius,
              onTap: (km) async {
                if (km > 0 && Locations.instance.searchFrom == null) {
                  await pickSearchPlace(context);
                  if (Locations.instance.searchFrom == null) return;
                }
                onRadius(km);
              },
            ),
          ]);
        },
      );
}

/// A form row for a saved location (profile, a job's address): shows the
/// chosen spot and opens the picker.
class LocationField extends StatelessWidget {
  final String label;
  final Place? value;
  final ValueChanged<Place?> onChanged;
  final String emptyText;
  final bool optional;
  const LocationField({super.key, required this.label, required this.value, required this.onChanged, this.emptyText = 'Not set', this.optional = true});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      FieldLabel(label, optional: optional),
      Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md), side: BorderSide(color: c.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final place = await pickPlace(context, title: label, current: v);
            if (place != null) onChanged(place);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              Icon(v == null ? AppIcons.gps : AppIcons.pinFill, size: 20, color: v == null ? c.muted : c.brand),
              Gap.w12,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(v == null ? emptyText : v.fullLabel, style: context.text.bodyLarge!.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600, color: v == null ? c.muted : c.ink)),
                  Text(v == null ? 'Tap to use your location, the map or the list' : 'Only the area and the distance are shown to others', style: context.text.bodySmall),
                ]),
              ),
              if (v != null && optional)
                IconButton(tooltip: 'Remove location', icon: Icon(AppIcons.close, size: 16, color: c.muted), onPressed: () => onChanged(null))
              else
                Icon(AppIcons.chevronRight, size: 14, color: c.muted),
            ]),
          ),
        ),
      ),
    ]);
  }
}
