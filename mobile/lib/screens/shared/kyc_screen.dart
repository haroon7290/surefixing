import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/media.dart';
import '../../widgets/states.dart';

/// Identity verification: ID details + document photos, reviewed by admins.
/// Verified users get a badge and rank higher in Smart Match.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _idNumber = TextEditingController();
  String _idType = 'cnic';
  Map<String, dynamic>? _existing;
  bool _loading = true;
  bool _saving = false;
  final Map<String, XFile?> _files = {'idFront': null, 'idBack': null, 'selfie': null};

  static const _slots = {
    'idFront': ('Front of ID', 'idFrontImage', Icons.badge_outlined, true),
    'idBack': ('Back of ID', 'idBackImage', Icons.flip_outlined, false),
    'selfie': ('Selfie holding ID', 'selfieImage', Icons.face_retouching_natural_outlined, true),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _idNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await AuthService.instance.refreshUser();
    try {
      final res = await ApiClient.get('/api/kyc/me');
      if (res is Map) {
        _existing = Map<String, dynamic>.from(res);
        _fullName.text = (_existing!['fullName'] ?? '').toString();
        _idNumber.text = (_existing!['idNumber'] ?? '').toString();
        _idType = (_existing!['idType'] ?? 'cnic').toString();
      } else {
        _fullName.text = AuthService.instance.user?.name ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String get _status => (_existing?['status'] ?? 'none').toString();
  bool get _locked => _status == 'approved' || _status == 'pending';

  bool _has(String slot) => _files[slot] != null || (_existing?[_slots[slot]!.$2] ?? '').toString().isNotEmpty;

  Future<void> _pick(String slot) async {
    if (_locked) return;
    final f = await pickImage(context);
    if (f != null) setState(() => _files[slot] = f);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_has('idFront') || !_has('selfie')) {
      toast('Add the front of your ID and a selfie', kind: ToastKind.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.multipart(
          '/api/kyc',
          {
            'fullName': _fullName.text.trim(),
            'idType': _idType,
            'idNumber': _idNumber.text.trim(),
          },
          files: _files);
      await AuthService.instance.refreshUser();
      toast('Submitted! We\'ll review it shortly.', kind: ToastKind.success);
      setState(() => _loading = true);
      await _load();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity verification')),
      body: _loading
          ? const SkeletonList(count: 3)
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  _statusCard(context),
                  const SizedBox(height: 20),
                  Text('ID details', style: context.text.titleSmall?.copyWith(fontSize: 15)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullName,
                    enabled: !_locked,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full legal name', prefixIcon: Icon(Icons.person_outline_rounded)),
                    validator: (v) => (v ?? '').trim().length < 3 ? 'Enter your name as on the ID' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _idType,
                    decoration: const InputDecoration(labelText: 'ID type', prefixIcon: Icon(Icons.badge_outlined)),
                    items: const [
                      DropdownMenuItem(value: 'cnic', child: Text('CNIC / National ID')),
                      DropdownMenuItem(value: 'passport', child: Text('Passport')),
                      DropdownMenuItem(value: 'driver_license', child: Text('Driving licence')),
                    ],
                    onChanged: _locked ? null : (v) => setState(() => _idType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _idNumber,
                    enabled: !_locked,
                    decoration: const InputDecoration(labelText: 'ID number', prefixIcon: Icon(Icons.numbers_rounded)),
                    validator: (v) => (v ?? '').trim().length < 4 ? 'Enter your ID number' : null,
                  ),
                  const SizedBox(height: 22),
                  Text('Documents', style: context.text.titleSmall?.copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Clear, well-lit photos. Only our review team can see them.',
                      style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _slot(context, 'idFront')),
                    const SizedBox(width: 10),
                    Expanded(child: _slot(context, 'idBack')),
                  ]),
                  const SizedBox(height: 10),
                  _slot(context, 'selfie', height: 170),
                ],
              ),
            ),
      bottomNavigationBar: _loading || _locked
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.verified_user_rounded),
                  label: Text(_status == 'rejected' ? 'Resubmit for review' : 'Submit for review'),
                ),
              ),
            ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final p = context.palette;
    final (Color color, IconData icon, String title, String body) = switch (_status) {
      'approved' => (
          p.success,
          Icons.verified_rounded,
          'You\'re verified',
          'Your profile shows the verified badge and ranks higher in Smart Match.'
        ),
      'pending' => (
          p.info,
          Icons.hourglass_top_rounded,
          'Under review',
          'We usually review submissions within one working day. We\'ll notify you.'
        ),
      'rejected' => (
          p.danger,
          Icons.error_outline_rounded,
          'Verification rejected',
          (_existing?['rejectionReason'] ?? '').toString().isEmpty
              ? 'Please check your details and resubmit.'
              : _existing!['rejectionReason'].toString()
        ),
      _ => (
          context.colors.primary,
          Icons.shield_outlined,
          'Get the verified badge',
          'Verified technicians and suppliers win more jobs — customers trust them more.'
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.text.titleMedium),
            const SizedBox(height: 4),
            Text(body, style: TextStyle(color: p.muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _slot(BuildContext context, String slot, {double height = 130}) {
    final (label, field, icon, required) = _slots[slot]!;
    final picked = _files[slot];
    final existing = (_existing?[field] ?? '').toString();
    final has = picked != null || existing.isNotEmpty;
    return InkWell(
      onTap: () => _pick(slot),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: has ? context.palette.success : context.palette.border, width: has ? 1.5 : 1),
          color: context.palette.fill,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (picked != null)
            LocalImage(picked, size: double.infinity)
          else if (existing.isNotEmpty)
            NetImage(existing)
          else
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: context.palette.subtle, size: 30),
              const SizedBox(height: 6),
              Text('$label${required ? ' *' : ''}',
                  style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          if (has)
            Positioned(
              right: 8,
              top: 8,
              child: CircleAvatar(
                  radius: 12,
                  backgroundColor: context.palette.success,
                  child: const Icon(Icons.check_rounded, size: 15, color: Colors.white)),
            ),
        ]),
      ),
    );
  }
}
