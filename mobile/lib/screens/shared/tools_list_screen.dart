import 'package:flutter/material.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../widgets/status_chip.dart';

class ToolsListScreen extends StatefulWidget {
  const ToolsListScreen({super.key});

  @override
  State<ToolsListScreen> createState() => _ToolsListScreenState();
}

class _ToolsListScreenState extends State<ToolsListScreen> {
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
      final res = await ApiClient.get('/api/tools') as List;
      setState(() => _tools = res.map((e) => Tool.fromJson(Map<String, dynamic>.from(e))).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rent(Tool t) async {
    final daysCtl = TextEditingController(text: '1');
    final days = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Rent ${t.name}'),
        content: TextField(
          controller: daysCtl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Days',
            helperText: '\$${t.rentPricePerDay.toStringAsFixed(2)} / day',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(daysCtl.text) ?? 1),
            child: const Text('Rent'),
          ),
        ],
      ),
    );
    if (days == null || days < 1) return;
    try {
      await ApiClient.post('/api/tools/${t.id}/rent', {'days': days});
      if (!mounted) return;
      final total = (days * t.rentPricePerDay).toStringAsFixed(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rented for $days days — total \$$total')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _buy(Tool t) async {
    if (t.installmentMonths <= 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Buy ${t.name} on installments'),
        content: Text(
          '${t.installmentMonths} months × \$${t.installmentMonthly.toStringAsFixed(2)}\n'
          'Total: \$${t.purchasePrice.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiClient.post('/api/tools/${t.id}/purchase');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Installment plan started')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tools.isEmpty
              ? ListView(children: const [SizedBox(height: 200), Center(child: Text('No tools listed yet'))])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _tools.length,
                  itemBuilder: (_, i) {
                    final t = _tools[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(t.name, style: Theme.of(context).textTheme.titleMedium)),
                                StatusChip(t.available ? 'active' : 'returned'),
                              ],
                            ),
                            if (t.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(t.description, style: const TextStyle(color: Colors.black54)),
                            ],
                            const SizedBox(height: 8),
                            Text('Rent: \$${t.rentPricePerDay.toStringAsFixed(2)} / day'),
                            Text('Buy: \$${t.purchasePrice.toStringAsFixed(2)}'
                                '${t.installmentMonths > 0 ? '  ·  ${t.installmentMonths} × \$${t.installmentMonthly.toStringAsFixed(2)}/mo' : ''}'),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(onPressed: () => _rent(t), child: const Text('Rent')),
                                const SizedBox(width: 8),
                                if (t.installmentMonths > 0)
                                  FilledButton(onPressed: () => _buy(t), child: const Text('Buy (installments)')),
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
