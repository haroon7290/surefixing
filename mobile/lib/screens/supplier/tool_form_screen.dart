import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/media.dart';
import '../../widgets/states.dart';

/// Add a new tool, or edit one ([toolId]) including photos and stock.
class ToolFormScreen extends StatefulWidget {
  final String? toolId;
  const ToolFormScreen({super.key, this.toolId});

  @override
  State<ToolFormScreen> createState() => _ToolFormScreenState();
}

class _ToolFormScreenState extends State<ToolFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController(text: AuthService.instance.user?.city ?? '');
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  final _price = TextEditingController();
  final _months = TextEditingController(text: '0');
  final _monthly = TextEditingController();
  final _stock = TextEditingController(text: '1');
  String _category = 'power';
  String _condition = 'good';
  bool _listed = true;
  bool _installments = false;
  List<String> _existing = [];
  final List<String> _removed = [];
  final List<XFile> _picked = [];
  bool _loading = false;
  bool _saving = false;

  bool get _editing => widget.toolId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _city, _rent, _deposit, _price, _months, _monthly, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  String _num(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = Tool.fromJson(await ApiClient.getMap('/api/tools/${widget.toolId}'));
      _name.text = t.name;
      _desc.text = t.description;
      _city.text = t.city;
      _rent.text = _num(t.rentPricePerDay);
      _deposit.text = _num(t.deposit);
      _price.text = _num(t.purchasePrice);
      _months.text = '${t.installmentMonths}';
      _monthly.text = _num(t.installmentMonthly);
      _stock.text = '${t.stock}';
      _category = Catalog.tools.any((c) => c.key == t.category) ? t.category : 'general';
      _condition = Catalog.toolConditions.containsKey(t.condition) ? t.condition : 'good';
      _listed = t.available;
      _installments = t.installmentMonths > 0;
      _existing = [...t.images];
    } catch (e) {
      toastError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _suggestMonthly() {
    final price = double.tryParse(_price.text) ?? 0;
    final months = int.tryParse(_months.text) ?? 0;
    if (price > 0 && months > 0 && _monthly.text.isEmpty) {
      _monthly.text = (price / months).ceil().toString();
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = <String, String>{
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'category': _category,
      'condition': _condition,
      'city': _city.text.trim(),
      'rentPricePerDay': _rent.text.trim().isEmpty ? '0' : _rent.text.trim(),
      'deposit': _deposit.text.trim().isEmpty ? '0' : _deposit.text.trim(),
      'purchasePrice': _price.text.trim().isEmpty ? '0' : _price.text.trim(),
      'installmentMonths': _installments ? (_months.text.trim().isEmpty ? '0' : _months.text.trim()) : '0',
      'installmentMonthly': _installments && _monthly.text.trim().isNotEmpty ? _monthly.text.trim() : '0',
      'stock': _stock.text.trim().isEmpty ? '0' : _stock.text.trim(),
      'available': '$_listed',
      if (_removed.isNotEmpty) 'removeImages': jsonEncode(_removed),
    };
    try {
      await ApiClient.multipart(_editing ? '/api/tools/${widget.toolId}' : '/api/tools', fields,
          method: _editing ? 'PATCH' : 'POST', multiFiles: {'images': _picked});
      toast(_editing ? 'Tool updated' : 'Tool listed!', kind: ToastKind.success);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete ${_name.text}?', message: 'Pending requests for this tool will be cancelled.', confirm: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await ApiClient.delete('/api/tools/${widget.toolId}');
      toast('Tool deleted');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      toastError(e);
    }
  }

  String? _money(String? v, {bool required = false}) {
    if ((v ?? '').trim().isEmpty) return required ? 'Required' : null;
    final n = double.tryParse(v!.trim());
    return n == null || n < 0 ? 'Enter a valid amount' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit tool' : 'Add a tool'),
        actions: [if (_editing) IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded))],
      ),
      body: _loading
          ? const SkeletonList(count: 3)
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  _h(context, 'Photos'),
                  PhotoPickerGrid(
                    existing: _existing,
                    picked: _picked,
                    max: 4,
                    onAdd: () async {
                      final f = await pickImage(context);
                      if (f != null) setState(() => _picked.add(f));
                    },
                    onRemoveExisting: (name) => setState(() {
                      _existing.remove(name);
                      _removed.add(name);
                    }),
                    onRemovePicked: (i) => setState(() => _picked.removeAt(i)),
                  ),
                  _h(context, 'Basics'),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Tool name', hintText: 'e.g. Bosch cordless drill 18V'),
                    validator: (v) => (v ?? '').trim().length < 2 ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _desc,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                        labelText: 'Description', alignLabelWithHint: true, hintText: 'What\'s included, power, size, accessories…'),
                  ),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in Catalog.tools)
                      ChoiceChip(
                        avatar: Icon(c.icon, size: 16, color: c.color),
                        label: Text(c.label),
                        selected: _category == c.key,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = c.key),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _condition,
                        decoration: const InputDecoration(labelText: 'Condition'),
                        items: [for (final e in Catalog.toolConditions.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                        onChanged: (v) => setState(() => _condition = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Pickup city'))),
                  ]),
                  _h(context, 'Pricing'),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rent,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Rent per day', prefixText: '${Fmt.currency} '),
                        validator: (v) => _money(v, required: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _deposit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Deposit', prefixText: '${Fmt.currency} '),
                        validator: _money,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sale price (optional)', prefixText: '${Fmt.currency} '),
                    validator: _money,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _installments,
                    onChanged: (v) => setState(() => _installments = v),
                    title: const Text('Offer installments', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Let customers buy and pay monthly'),
                  ),
                  if (_installments)
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _months,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Months'),
                          onChanged: (_) => _suggestMonthly(),
                          validator: (v) => _installments && (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Months > 0' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _monthly,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Per month', prefixText: '${Fmt.currency} '),
                          validator: (v) => _money(v, required: _installments),
                        ),
                      ),
                    ]),
                  _h(context, 'Availability'),
                  TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Units in stock'),
                    validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0 ? 'Enter 0 or more' : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _listed,
                    onChanged: (v) => setState(() => _listed = v),
                    title: const Text('Listed in the marketplace', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_listed ? 'Customers can find and rent it' : 'Hidden from customers',
                        style: TextStyle(color: context.palette.muted)),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : Text(_editing ? 'Save changes' : 'List tool'),
          ),
        ),
      ),
    );
  }

  Widget _h(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 0, 10),
        child: Text(t, style: context.text.titleSmall?.copyWith(fontSize: 15)),
      );
}
