import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'technician_profile_screen.dart';

/// Simple browsable directory so a client can look through technicians and
/// their reviews without needing an active job/bid first.
class TechniciansListScreen extends StatefulWidget {
  const TechniciansListScreen({super.key});

  @override
  State<TechniciansListScreen> createState() => _TechniciansListScreenState();
}

class _TechniciansListScreenState extends State<TechniciansListScreen> {
  List<dynamic> _technicians = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/users/technicians') as List;
      if (!mounted) return;
      setState(() => _technicians = res);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: _technicians.isEmpty
          ? ListView(children: const [
              SizedBox(height: 200),
              Center(child: Text('No technicians registered yet.')),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _technicians.length,
              itemBuilder: (_, i) {
                final t = Map<String, dynamic>.from(_technicians[i]);
                final rating = (t['rating'] ?? 0).toDouble();
                final ratingCount = t['ratingCount'] ?? 0;
                final skills = (t['skills'] as List?)?.cast<String>() ?? [];
                final kycApproved = t['kycStatus'] == 'approved';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.withOpacity(0.1),
                      child: Text(
                        (t['name'] ?? '?').toString().isNotEmpty
                            ? t['name'][0].toString().toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.indigo),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(t['name'] ?? '', overflow: TextOverflow.ellipsis)),
                        if (kycApproved) const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ),
                    subtitle: Text(
                      '${rating.toStringAsFixed(1)} ★ ($ratingCount)'
                      '${skills.isNotEmpty ? ' · ${skills.take(3).join(', ')}' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TechnicianProfileScreen(technicianId: t['id']),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}