import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _fullName = TextEditingController();
  final _idNumber = TextEditingController();
  String _idType = 'cnic';
  bool _saving = false;
  Map<String, dynamic>? _existing;
  bool _loading = true;

  final _picker = ImagePicker();
  XFile? _idFront;
  XFile? _idBack;
  XFile? _selfie;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Pull a fresh user object so kycStatus reflects any admin verdict
    // that happened while this device was offline.
    await AuthService.instance.refreshUser();
    try {
      final res = await ApiClient.get('/api/kyc/me');
      if (res is Map) {
        setState(() {
          _existing = Map<String, dynamic>.from(res);
          _fullName.text = _existing?['fullName'] ?? '';
          _idNumber.text = _existing?['idNumber'] ?? '';
          _idType = _existing?['idType'] ?? 'cnic';
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isLocked =>
      _existing != null && _existing!['status'] == 'approved';

  Future<void> _pickImage(String slot) async {
    if (_isLocked) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() {
      switch (slot) {
        case 'idFront':
          _idFront = file;
          break;
        case 'idBack':
          _idBack = file;
          break;
        case 'selfie':
          _selfie = file;
          break;
      }
    });
  }

  bool get _hasRequiredImages {
    final needsFront = _idFront != null || (_existing?['idFrontImage'] ?? '').toString().isNotEmpty;
    final needsSelfie = _selfie != null || (_existing?['selfieImage'] ?? '').toString().isNotEmpty;
    return needsFront && needsSelfie;
  }

  Future<void> _submit() async {
    if (_fullName.text.trim().isEmpty || _idNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name and ID number are required')),
      );
      return;
    }
    if (!_hasRequiredImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your ID front photo and a selfie')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.postMultipart(
        '/api/kyc',
        {
          'fullName': _fullName.text.trim(),
          'idType': _idType,
          'idNumber': _idNumber.text.trim(),
        },
        files: {
          'idFront': _idFront,
          'idBack': _idBack,
          'selfie': _selfie,
        },
      );
      await AuthService.instance.refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KYC submitted for review')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _imageSlot(String slot, String label, XFile? picked, String? existingFilename) {
    return GestureDetector(
      onTap: () => _pickImage(slot),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade50,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (picked != null)
              FutureBuilder<Uint8List>(
                future: picked.readAsBytes(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  return Image.memory(snap.data!, fit: BoxFit.cover);
                },
              )
            else if (existingFilename != null && existingFilename.isNotEmpty)
              Image.network(
                ApiConfig.mediaUrl(existingFilename),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(label),
              )
            else
              _placeholder(label),
            if (!_isLocked)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade500, size: 28),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('KYC verification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current status: ${user.kycStatus}',
                            style: Theme.of(context).textTheme.titleMedium),
                        if (_existing != null && _existing!['rejectionReason'] != null && (_existing!['rejectionReason'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Rejection reason: ${_existing!['rejectionReason']}',
                                style: const TextStyle(color: Colors.red)),
                          ),
                        if (_isLocked)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Your KYC is approved and locked. Contact support if you need to change it.',
                              style: TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _fullName,
                  enabled: !_isLocked,
                  decoration: const InputDecoration(labelText: 'Full legal name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _idType,
                  items: const [
                    DropdownMenuItem(value: 'cnic', child: Text('CNIC / National ID')),
                    DropdownMenuItem(value: 'passport', child: Text('Passport')),
                    DropdownMenuItem(value: 'driver_license', child: Text('Driver license')),
                  ],
                  onChanged: _isLocked ? null : (v) => setState(() => _idType = v!),
                  decoration: const InputDecoration(labelText: 'ID type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _idNumber,
                  enabled: !_isLocked,
                  decoration: const InputDecoration(labelText: 'ID number'),
                ),
                const SizedBox(height: 20),
                Text('Documents', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _imageSlot('idFront', 'ID front *', _idFront, _existing?['idFrontImage']),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _imageSlot('idBack', 'ID back', _idBack, _existing?['idBackImage']),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _imageSlot('selfie', 'Selfie holding your ID *', _selfie, _existing?['selfieImage']),
                const SizedBox(height: 8),
                Text(
                  '* Required. Tap a box to take a photo or choose one from your gallery.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 20),
                if (!_isLocked)
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit for review'),
                  ),
              ],
            ),
    );
  }
}