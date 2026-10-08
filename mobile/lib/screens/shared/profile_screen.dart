import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  late final TextEditingController _skills;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = AuthService.instance.user!;
    _name = TextEditingController(text: u.name);
    _phone = TextEditingController(text: u.phone ?? '');
    _bio = TextEditingController(text: u.bio);
    _skills = TextEditingController(text: u.skills.join(', '));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.patch('/api/users/me', {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'bio': _bio.text.trim(),
        'skills': _skills.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      });
      await AuthService.instance.refreshUser();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Role: ${user.role}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (user.role == 'technician') ...[
            Text('Rating: ${user.rating.toStringAsFixed(1)} (${user.ratingCount})'),
            Text('Jobs completed: ${user.jobsCompleted} / ${user.jobsAssigned} assigned'),
            Text('Avg response: ${user.avgResponseMinutes.toStringAsFixed(0)} min'),
            Text('KYC: ${user.kycStatus}'),
            const SizedBox(height: 12),
          ],
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          if (user.role == 'technician') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _skills,
              decoration: const InputDecoration(
                labelText: 'Skills (comma-separated)',
                hintText: 'plumbing, electrical, carpentry',
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
