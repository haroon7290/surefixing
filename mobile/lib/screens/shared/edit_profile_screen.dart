import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/media.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _user = AuthService.instance.user!;
  late final _name = TextEditingController(text: _user.name);
  late final _phone = TextEditingController(text: _user.phone ?? '');
  late final _city = TextEditingController(text: _user.city);
  late final _bio = TextEditingController(text: _user.bio);
  late final _headline = TextEditingController(text: _user.headline);
  late final _rate = TextEditingController(text: _user.hourlyRate > 0 ? _user.hourlyRate.toStringAsFixed(0) : '');
  late final _years = TextEditingController(text: _user.experienceYears > 0 ? '${_user.experienceYears}' : '');
  final _customSkill = TextEditingController();
  late final Set<String> _skills = {..._user.skills};
  late bool _available = _user.isAvailable;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _bio, _headline, _rate, _years, _customSkill]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService.instance.updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'bio': _bio.text.trim(),
        if (_user.isTechnician || _user.isSupplier) 'headline': _headline.text.trim(),
        if (_user.isTechnician) ...{
          'skills': _skills.toList(),
          'hourlyRate': double.tryParse(_rate.text.trim()) ?? 0,
          'experienceYears': int.tryParse(_years.text.trim()) ?? 0,
          'isAvailable': _available,
        },
      });
      toast('Profile saved', kind: ToastKind.success);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _photo() async {
    final f = await pickImage(context, maxWidth: 800);
    if (f == null) return;
    try {
      await AuthService.instance.uploadAvatar(f);
      if (mounted) setState(() {});
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.user!;
    final customSkills = _skills.where((s) => !Catalog.services.any((c) => c.key == s)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Center(
              child: GestureDetector(
                onTap: _photo,
                child: Column(children: [
                  AppAvatar(name: u.name, url: u.avatar, size: 96),
                  const SizedBox(height: 8),
                  Text('Change photo', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                      controller: _city,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city_outlined)))),
            ]),
            if (u.isTechnician || u.isSupplier) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _headline,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Headline',
                  hintText: u.isTechnician ? 'e.g. Licensed electrician & plumber' : 'e.g. Professional tools since 2015',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
            ],
            const SizedBox(height: 4),
            TextFormField(
              controller: _bio,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                  labelText: 'About', alignLabelWithHint: true, hintText: 'Tell customers about your experience and how you work'),
            ),
            if (u.isTechnician) ...[
              const SizedBox(height: 8),
              Text('Professional details', style: context.text.titleSmall?.copyWith(fontSize: 15)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _rate,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hourly rate', prefixText: '${Fmt.currency} '),
                    validator: (v) => (v ?? '').isEmpty || double.tryParse(v!) != null ? null : 'Enter a number',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _years,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Years of experience'),
                    validator: (v) => (v ?? '').isEmpty || int.tryParse(v!) != null ? null : 'Whole years',
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                title: const Text('Available for new jobs', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Turn off when you\'re fully booked — you\'ll rank lower in Smart Match.'),
              ),
              const SizedBox(height: 8),
              Text('Skills', style: context.text.titleSmall?.copyWith(fontSize: 15)),
              const SizedBox(height: 4),
              Text('Pick every trade you do. Matching skills is the biggest factor in AI ranking.',
                  style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in Catalog.services)
                  FilterChip(
                    avatar: Icon(c.icon, size: 16, color: c.color),
                    label: Text(c.label),
                    selected: _skills.contains(c.key),
                    onSelected: (v) => setState(() => v ? _skills.add(c.key) : _skills.remove(c.key)),
                  ),
                for (final s in customSkills) InputChip(label: Text(Fmt.titleCase(s)), onDeleted: () => setState(() => _skills.remove(s))),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _customSkill,
                decoration: InputDecoration(
                  hintText: 'Add another skill (e.g. solar panels)',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () {
                      final s = _customSkill.text.trim().toLowerCase();
                      if (s.isEmpty) return;
                      setState(() => _skills.add(s));
                      _customSkill.clear();
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Text('Save changes'),
          ),
        ),
      ),
    );
  }
}
