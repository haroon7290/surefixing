import 'package:flutter/material.dart';

import '../../kit.dart';
import '../location/location_picker.dart';

/// Edit the signed-in user's profile. Technicians also manage their
/// professional details and portfolio here.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final User _u = Session.instance.user!;
  late final _name = TextEditingController(text: _u.name);
  late final _phone = TextEditingController(text: _u.phone);
  late final _address = TextEditingController(text: _u.address);
  late final _bio = TextEditingController(text: _u.bio);
  late final _headline = TextEditingController(text: _u.headline);
  late final _rate = TextEditingController(text: _u.hourlyRate > 0 ? '${_u.hourlyRate.round()}' : '');
  late final _years = TextEditingController(text: _u.experienceYears > 0 ? '${_u.experienceYears}' : '');
  late String? _city = cities.contains(_u.city) ? _u.city : null;
  late final Set<String> _skills = {..._u.skills};
  late Place? _place = _u.geo == null ? null : Place(point: _u.geo!, area: _u.area, city: _u.city, source: 'profile');
  bool _placeChanged = false;
  late int _radius = _u.serviceRadiusKm;
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _bio, _headline, _rate, _years]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await Session.instance.updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city ?? _u.city,
        'address': _address.text.trim(),
        'bio': _bio.text.trim(),
        if (_placeChanged && _place == null) 'clearLocation': true,
        if (_placeChanged && _place != null) ...{'lat': _place!.point.lat, 'lng': _place!.point.lng, 'area': _place!.area},
        if (_u.isTechnician) ...{
          'serviceRadiusKm': _radius,
          'headline': _headline.text.trim(),
          'skills': _skills.toList(),
          'hourlyRate': double.tryParse(_rate.text) ?? 0,
          'experienceYears': int.tryParse(_years.text) ?? 0,
        },
      });
      // A newly saved location becomes where searches start from on this device.
      if (_placeChanged) await Locations.instance.choose(null);
      toastOk('Profile saved');
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPortfolio(int room) async {
    final files = await pickPhotos(max: room);
    if (files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      await Session.instance.addPortfolio(files);
      toastOk('Added to your portfolio');
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tech = _u.isTechnician;
    final supplier = _u.isSupplier;

    final basics = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Field(label: supplier ? 'Business or full name' : 'Full name', controller: _name, icon: AppIcons.user, capitalization: TextCapitalization.words, validator: minLength(2, 'Enter your name')),
        Gap.h16,
        Field(label: 'Phone', hint: '0300-1234567', controller: _phone, icon: AppIcons.phone, keyboardType: TextInputType.phone, helper: 'Shared only with people you work with.'),
        Gap.h16,
        SelectField<String>(label: 'City', hint: 'Choose your city', value: _city, icon: AppIcons.city, items: {for (final c in cities) c: c}, onChanged: (v) => setState(() => _city = v)),
        Gap.h16,
        LocationField(
          label: supplier ? 'Shop location' : (tech ? 'Where you work from' : 'Your location'),
          value: _place,
          onChanged: (p) => setState(() {
            _place = p;
            _placeChanged = true;
            if (p != null && cities.contains(p.city)) _city = p.city;
          }),
        ),
        Gap.h6,
        Text(
          supplier
              ? 'Customers see how far your tools are from them. Your exact spot is never shown.'
              : (tech ? 'Clients near you see you first, with the distance. Your exact spot is never shown.' : 'Used to find technicians and tools near you. Never shown to anyone.'),
          style: context.text.bodySmall,
        ),
        Gap.h16,
        Field(
          label: supplier ? 'Shop / pickup address' : 'Address',
          hint: 'House or shop, street, area',
          controller: _address,
          icon: AppIcons.pin,
          maxLength: 300,
          optional: !supplier,
          helper: supplier ? 'Customers get this after you approve a pickup rental.' : 'Used as your default for jobs and deliveries. Never shown on your public profile.',
        ),
        Gap.h16,
        Field(
            label: tech ? 'About you' : 'Bio',
            hint: tech ? 'Your experience, what you specialise in, how you work…' : 'A line or two about you',
            controller: _bio,
            maxLines: 5,
            minLines: 3,
            maxLength: 1000,
            optional: true,
            capitalization: TextCapitalization.sentences),
      ]),
    );

    final pro = !tech
        ? null
        : Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text('Professional profile', style: context.text.titleMedium),
              Gap.h4,
              Text('This is what clients and the AI ranking see.', style: context.text.bodySmall),
              Gap.h16,
              Field(label: 'Headline', hint: 'e.g. Master plumber · 12 years', controller: _headline, maxLength: 100, capitalization: TextCapitalization.sentences),
              Gap.h16,
              const FieldLabel('Skills'),
              Pills<CatalogItem>(
                values: serviceCategories,
                label: (c) => c.label,
                icon: (c) => c.icon,
                selectedSet: {
                  for (final c in serviceCategories)
                    if (_skills.contains(c.key)) c
                },
                onTap: (c) => setState(() => _skills.contains(c.key) ? _skills.remove(c.key) : _skills.add(c.key)),
              ),
              Gap.h16,
              const FieldLabel('How far you travel for work'),
              Pills<int>(
                values: ({5, 10, 15, 20, 30, 50, _radius}.toList()..sort()),
                label: (km) => '$km km',
                selected: _radius,
                onTap: (km) => setState(() => _radius = km),
              ),
              Gap.h6,
              Text('Jobs farther than this are still shown to you, marked as outside your area.', style: context.text.bodySmall),
              Gap.h16,
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Field(label: 'Hourly rate', hint: '1500', prefixText: 'Rs  ', controller: _rate, keyboardType: TextInputType.number, formatters: Field.digits, optional: true)),
                Gap.w12,
                Expanded(child: Field(label: 'Years of experience', hint: '5', controller: _years, keyboardType: TextInputType.number, formatters: Field.digits, optional: true)),
              ]),
            ]),
          );

    final portfolio = !tech
        ? null
        : ListenableBuilder(
            listenable: Session.instance,
            builder: (context, _) {
              final photos = Session.instance.user?.portfolio ?? const <String>[];
              final room = 8 - photos.length;
              return Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: Text('Portfolio', style: context.text.titleMedium)),
                    Text('${photos.length} / 8', style: context.text.bodySmall),
                  ]),
                  Gap.h4,
                  Text('Photos of finished work help clients choose you.', style: context.text.bodySmall),
                  Gap.h12,
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final file in photos)
                      Stack(clipBehavior: Clip.none, children: [
                        ClipRRect(borderRadius: BorderRadius.circular(R.md), child: NetImage(file, width: 88, height: 88)),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: RoundBtn(AppIcons.close, tooltip: 'Remove photo', size: 26, background: context.colors.ink, color: context.colors.canvas, bordered: false, onPressed: () async {
                            try {
                              await Session.instance.removePortfolio(file);
                            } catch (e) {
                              toastError(e);
                            }
                          }),
                        ),
                      ]),
                    if (room > 0) Btn(_uploading ? 'Uploading…' : 'Add photos', icon: AppIcons.camera, kind: BtnKind.soft, loading: _uploading, onPressed: () => _addPortfolio(room)),
                  ]),
                ]),
              );
            },
          );

    Widget gap(Widget? w) => w == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 16), child: w);
    return AppPage(
      title: 'Edit profile',
      maxWidth: tech ? 1120 : 720,
      bottom: Btn('Save changes', size: BtnSize.lg, expand: true, loading: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: PageList(children: [
          if (tech)
            TwoCol(sideWidth: 440, main: Column(mainAxisSize: MainAxisSize.min, children: [gap(basics)]), side: Column(mainAxisSize: MainAxisSize.min, children: [gap(pro), gap(portfolio)]))
          else
            basics,
        ]),
      ),
    );
  }
}
