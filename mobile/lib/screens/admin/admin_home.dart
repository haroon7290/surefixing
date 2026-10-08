import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/status_chip.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _StatsTab(),
      const _UsersTab(),
      const _KycTab(),
    ];
    final titles = ['Dashboard', 'Users', 'KYC review'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      drawer: const AppDrawer(),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.verified_user), label: 'KYC'),
        ],
      ),
    );
  }
}

class _StatsTab extends StatefulWidget {
  const _StatsTab();
  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.get('/api/admin/stats');
      setState(() => _stats = Map<String, dynamic>.from(res));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_stats == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(label: 'Users', value: '${_stats!['users']}', icon: Icons.group),
          _StatCard(label: 'Jobs', value: '${_stats!['jobs']}', icon: Icons.build),
          _StatCard(label: 'Tools', value: '${_stats!['tools']}', icon: Icons.hardware),
          _StatCard(label: 'Pending KYC', value: '${_stats!['pendingKyc']}', icon: Icons.verified_user),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.indigo),
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List _users = [];
  String _role = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = _role.isEmpty ? <String, String>{} : {'role': _role};
      final res = await ApiClient.get('/api/admin/users', query: q) as List;
      setState(() => _users = res);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.delete('/api/admin/users/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '', label: Text('All')),
              ButtonSegment(value: 'client', label: Text('Clients')),
              ButtonSegment(value: 'technician', label: Text('Techs')),
              ButtonSegment(value: 'supplier', label: Text('Suppliers')),
            ],
            selected: {_role},
            onSelectionChanged: (s) {
              setState(() => _role = s.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (_, i) {
                      final u = _users[i];
                      final isMe = (u['id']?.toString() ?? '') ==
                          AuthService.instance.user!.id;
                      return ListTile(
                        leading: CircleAvatar(child: Text((u['name'] as String).isNotEmpty ? u['name'][0] : '?')),
                        title: Row(children: [
                          Expanded(child: Text(u['name'] ?? '')),
                          if (isMe)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('You',
                                  style: TextStyle(color: Colors.indigo, fontSize: 11)),
                            ),
                        ]),
                        subtitle: Text('${u['email']} · ${u['role']} · KYC ${u['kycStatus']}'),
                        trailing: isMe
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _remove(u['id']),
                              ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _KycTab extends StatefulWidget {
  const _KycTab();
  @override
  State<_KycTab> createState() => _KycTabState();
}

class _KycTabState extends State<_KycTab> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/admin/kyc') as List;
      setState(() => _items = res);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(String id, String decision) async {
    String? reason;
    if (decision == 'rejected') {
      final c = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Rejection reason'),
          content: TextField(controller: c, maxLines: 3),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Reject')),
          ],
        ),
      );
      if (reason == null) return;
    }
    try {
      await ApiClient.post('/api/admin/kyc/$id/verify', {
        'decision': decision,
        if (reason != null) 'reason': reason,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('KYC $decision')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('No KYC submissions'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final k = _items[i];
          final u = k['user'] ?? {};
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(k['fullName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      StatusChip(k['status'] ?? 'pending'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('User: ${u['name']} (${u['role']})'),
                  Text('${k['idType']} · ${k['idNumber']}'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _KycThumb(label: 'ID front', filename: k['idFrontImage']),
                      const SizedBox(width: 8),
                      _KycThumb(label: 'ID back', filename: k['idBackImage']),
                      const SizedBox(width: 8),
                      _KycThumb(label: 'Selfie', filename: k['selfieImage']),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (k['status'] == 'pending')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _decide(k['_id'], 'rejected'),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _decide(k['_id'], 'approved'),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small tappable thumbnail for a KYC document image. Shows a placeholder
/// box when no image was submitted for that slot; tapping a real image
/// opens it full-screen so the admin can actually inspect it before
/// approving or rejecting.
class _KycThumb extends StatelessWidget {
  final String label;
  final String? filename;
  const _KycThumb({required this.label, required this.filename});

  bool get _hasImage => filename != null && filename!.isNotEmpty;

  void _openFullScreen(BuildContext context) {
    if (!_hasImage) return;
    final url = ApiConfig.mediaUrl(filename!);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(label)),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _openFullScreen(context),
        child: Column(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade100,
              ),
              clipBehavior: Clip.antiAlias,
              child: _hasImage
                  ? Image.network(
                      ApiConfig.mediaUrl(filename!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                    )
                  : Icon(Icons.no_photography_outlined, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}