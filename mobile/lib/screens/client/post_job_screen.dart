import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';

const _maxImages = 5;

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _budget = TextEditingController();
  final _location = TextEditingController();
  String _category = 'plumbing';
  bool _saving = false;

  final _picker = ImagePicker();
  final List<XFile> _images = [];

  Future<void> _addImage() async {
    if (_images.length >= _maxImages) return;
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
    setState(() => _images.add(file));
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.postMultipart(
        '/api/jobs',
        {
          'title': _title.text.trim(),
          'description': _desc.text.trim(),
          'category': _category,
          'budget': (double.tryParse(_budget.text) ?? 0).toString(),
          'location': _location.text.trim(),
        },
        multiFiles: {'images': _images},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job posted')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _imageTile(int index) {
    final file = _images[index];
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              return Image.memory(snap.data!, width: 90, height: 90, fit: BoxFit.cover);
            },
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile() {
    return GestureDetector(
      onTap: _addImage,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade50,
        ),
        child: Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Describe the work'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'plumbing', child: Text('Plumbing')),
              DropdownMenuItem(value: 'electrical', child: Text('Electrical')),
              DropdownMenuItem(value: 'carpentry', child: Text('Carpentry')),
              DropdownMenuItem(value: 'painting', child: Text('Painting')),
              DropdownMenuItem(value: 'appliance', child: Text('Appliance repair')),
              DropdownMenuItem(value: 'general', child: Text('General')),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budget,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Budget (\$)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location / address')),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Photos', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 6),
              Text('(${_images.length}/$_maxImages)', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < _images.length; i++) _imageTile(i),
              if (_images.length < _maxImages) _addTile(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Optional, but photos help technicians understand the job and bid accurately.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}