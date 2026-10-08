import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class AddToolScreen extends StatefulWidget {
  const AddToolScreen({super.key});

  @override
  State<AddToolScreen> createState() => _AddToolScreenState();
}

class _AddToolScreenState extends State<AddToolScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _rent = TextEditingController(text: '10');
  final _price = TextEditingController(text: '100');
  final _installMonths = TextEditingController(text: '0');
  final _monthly = TextEditingController(text: '0');
  final _stock = TextEditingController(text: '1');
  String _category = 'power';
  bool _saving = false;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiClient.post('/api/tools', {
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'rentPricePerDay': double.tryParse(_rent.text) ?? 0,
        'purchasePrice': double.tryParse(_price.text) ?? 0,
        'installmentMonths': int.tryParse(_installMonths.text) ?? 0,
        'installmentMonthly': double.tryParse(_monthly.text) ?? 0,
        'stock': int.tryParse(_stock.text) ?? 1,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tool added')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add tool')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tool name')),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            items: const [
              DropdownMenuItem(value: 'power', child: Text('Power tool')),
              DropdownMenuItem(value: 'hand', child: Text('Hand tool')),
              DropdownMenuItem(value: 'measurement', child: Text('Measurement')),
              DropdownMenuItem(value: 'plumbing', child: Text('Plumbing')),
              DropdownMenuItem(value: 'electrical', child: Text('Electrical')),
              DropdownMenuItem(value: 'general', child: Text('General')),
            ],
            onChanged: (v) => setState(() => _category = v!),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rent,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Rent price per day (\$)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Purchase price (\$)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _installMonths,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Installment months (0 = off)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _monthly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly (\$)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Stock'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add tool'),
          ),
        ],
      ),
    );
  }
}
