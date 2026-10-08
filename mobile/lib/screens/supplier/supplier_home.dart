import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_drawer.dart';
import 'add_tool_screen.dart';

class SupplierHome extends StatefulWidget {
  const SupplierHome({super.key});

  @override
  State<SupplierHome> createState() => _SupplierHomeState();
}

class _SupplierHomeState extends State<SupplierHome> {
  int _tab = 0;
  int _toolsKey = 0;
  int _rentalsKey = 0;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = RealtimeService.instance.events.listen((e) {
      if (e.name == 'tool:rented' || e.name == 'tool:purchased') {
        if (!mounted) return;
        // Bump both keys so whichever tab is visible (and the other when it
        // mounts next) reloads with the new state.
        setState(() {
          _toolsKey++;
          _rentalsKey++;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _MyToolsTab(key: ValueKey(_toolsKey)),
      _IncomingRentalsTab(key: ValueKey(_rentalsKey)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_tab == 0 ? 'My tools' : 'Incoming rentals')),
      drawer: const AppDrawer(),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.hardware), label: 'Tools'),
          NavigationDestination(icon: Icon(Icons.inbox), label: 'Rentals'),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddToolScreen()),
                );
                if (added == true && mounted) setState(() => _toolsKey++);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add tool'),
            )
          : null,
    );
  }
}

class _MyToolsTab extends StatefulWidget {
  const _MyToolsTab({super.key});
  @override
  State<_MyToolsTab> createState() => _MyToolsTabState();
}

class _MyToolsTabState extends State<_MyToolsTab> {
  List<Tool> _tools = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/tools', query: {'mine': '1'}) as List;
      setState(() => _tools = res.map((e) => Tool.fromJson(Map<String, dynamic>.from(e))).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Tool t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${t.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.delete('/api/tools/${t.id}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${t.name}')),
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
    return RefreshIndicator(
      onRefresh: _load,
      child: _tools.isEmpty
          ? ListView(children: const [
              SizedBox(height: 200),
              Center(child: Text('No tools listed. Tap "Add tool".')),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tools.length,
              itemBuilder: (_, i) {
                final t = _tools[i];
                return Card(
                  child: ListTile(
                    title: Text(t.name),
                    subtitle: Text(
                      'Rent \$${t.rentPricePerDay.toStringAsFixed(2)}/day · '
                      'Buy \$${t.purchasePrice.toStringAsFixed(2)} · stock ${t.stock}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _delete(t),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _IncomingRentalsTab extends StatefulWidget {
  const _IncomingRentalsTab({super.key});
  @override
  State<_IncomingRentalsTab> createState() => _IncomingRentalsTabState();
}

class _IncomingRentalsTabState extends State<_IncomingRentalsTab> {
  List _rentals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/tools/me/incoming') as List;
      setState(() => _rentals = res);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final fmt = DateFormat.yMMMd().add_jm();
    return RefreshIndicator(
      onRefresh: _load,
      child: _rentals.isEmpty
          ? ListView(children: const [
              SizedBox(height: 200),
              Center(child: Text('No rentals or purchases yet.')),
            ])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _rentals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = _rentals[i];
                final tool = (r['tool'] is Map ? r['tool'] : {}) as Map;
                final renter = (r['renter'] is Map ? r['renter'] : {}) as Map;
                final created = DateTime.tryParse(r['createdAt'] ?? '') ?? DateTime.now();
                final isInstall = r['type'] == 'installment';
                return Card(
                  child: ListTile(
                    leading: Icon(isInstall ? Icons.shopping_bag : Icons.schedule),
                    title: Text('${tool['name'] ?? 'Tool'} — ${renter['name'] ?? 'someone'}'),
                    subtitle: Text(
                      isInstall
                          ? 'Installment purchase · \$${(r['totalCost'] ?? 0).toStringAsFixed(2)} over ${r['monthsRemaining'] ?? 0} months\n${fmt.format(created)}'
                          : 'Rented for ${r['days'] ?? 0}d · \$${(r['totalCost'] ?? 0).toStringAsFixed(2)}\n${fmt.format(created)}',
                    ),
                    isThreeLine: true,
                    trailing: Text(r['status'] ?? '', style: const TextStyle(fontSize: 12)),
                  ),
                );
              },
            ),
    );
  }
}
