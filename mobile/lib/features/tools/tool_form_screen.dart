import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../kit.dart';

/// Add or edit a tool listing.
class ToolFormScreen extends StatefulWidget {
  final Tool? tool;
  const ToolFormScreen({super.key, this.tool});

  @override
  State<ToolFormScreen> createState() => _ToolFormScreenState();
}

class _ToolFormScreenState extends State<ToolFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Tool? _tool = widget.tool;
  String _num(double? v) => v == null || v == 0 ? '' : '${v.round()}';
  late final _name = TextEditingController(text: _tool?.name ?? '');
  late final _description = TextEditingController(text: _tool?.description ?? '');
  late final _rent = TextEditingController(text: _num(_tool?.rentPricePerDay));
  late final _deposit = TextEditingController(text: _num(_tool?.deposit));
  late final _price = TextEditingController(text: _num(_tool?.purchasePrice));
  late final _months = TextEditingController(text: (_tool?.installmentMonths ?? 0) == 0 ? '' : '${_tool!.installmentMonths}');
  late String _category = _tool?.category ?? 'power';
  late String _condition = _tool?.condition ?? 'good';
  late String? _city = cities.contains(_tool?.city ?? Session.instance.user?.city) ? (_tool?.city ?? Session.instance.user!.city) : null;
  late int _stock = _tool?.stock ?? 1;
  late bool _available = _tool?.available ?? true;
  late bool _sells = _tool?.hasInstallments ?? false;
  late List<String> _existing = [...?_tool?.images];
  final List<String> _removed = [];
  List<XFile> _photos = [];
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _rent, _deposit, _price, _months]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _monthly {
    final price = double.tryParse(_price.text) ?? 0;
    final months = int.tryParse(_months.text) ?? 0;
    return months <= 0 ? 0 : (price / months).ceilToDouble();
  }

  Future<void> _save() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final fields = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'category': _category,
      'condition': _condition,
      'city': _city ?? '',
      'rentPricePerDay': _rent.text,
      'deposit': _deposit.text.isEmpty ? '0' : _deposit.text,
      'stock': '$_stock',
      'available': '$_available',
      'purchasePrice': _sells ? _price.text : '0',
      'installmentMonths': _sells ? _months.text : '0',
      'installmentMonthly': _sells ? '${_monthly.round()}' : '0',
      if (_removed.isNotEmpty) 'removeImages': _removed.join(','),
    };
    try {
      if (_tool == null) {
        await Api.upload('/api/tools', fields: fields, files: {'images': _photos});
        toastOk('Tool listed');
      } else {
        await Api.upload('/api/tools/${_tool.id}', method: 'PATCH', fields: fields, files: {'images': _photos});
        toastOk('Changes saved');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      toastError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context,
        title: 'Delete "${_tool!.name}"?', message: 'Pending requests are cancelled and refunded. This cannot be undone.', confirmLabel: 'Delete', danger: true, icon: AppIcons.trash)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.delete('/api/tools/${_tool.id}');
      toast('Tool deleted');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      toastError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = _tool != null;
    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const FieldLabel('Photos'),
          PhotoPicker(
            picked: _photos,
            existing: _existing,
            max: 4,
            onChanged: (v) => setState(() => _photos = v),
            onRemoveExisting: (f) => setState(() {
              _existing = _existing.where((x) => x != f).toList();
              _removed.add(f);
            }),
          ),
          Gap.h20,
          Field(label: 'Tool name', hint: 'e.g. Bosch hammer drill 800W', controller: _name, maxLength: 100, capitalization: TextCapitalization.words, validator: minLength(2, 'Enter the tool name')),
          Gap.h16,
          Field(
              label: 'Description',
              hint: 'What it is good for, what is included (bits, case, charger)…',
              controller: _description,
              maxLines: 4,
              minLines: 3,
              maxLength: 2000,
              optional: true,
              capitalization: TextCapitalization.sentences),
        ]),
      ),
      Gap.h16,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const FieldLabel('Category'),
          Pills<CatalogItem>(values: toolCategories, label: (c) => c.label, icon: (c) => c.icon, selected: toolCategory(_category), onTap: (c) => setState(() => _category = c.key)),
          Gap.h20,
          const FieldLabel('Condition'),
          Pills<String>(values: toolConditions.keys.toList(), label: (k) => toolConditions[k]!, selected: _condition, onTap: (k) => setState(() => _condition = k)),
        ]),
      ),
    ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Field(
                    label: 'Rent per day',
                    hint: '800',
                    prefixText: 'Rs  ',
                    controller: _rent,
                    keyboardType: TextInputType.number,
                    formatters: Field.digits,
                    validator: positiveNumber('Enter a daily rate'))),
            Gap.w12,
            Expanded(child: Field(label: 'Deposit', hint: '2000', prefixText: 'Rs  ', controller: _deposit, keyboardType: TextInputType.number, formatters: Field.digits, optional: true)),
          ]),
          Gap.h8,
          Text('The deposit is refunded on return. Each late day costs one day of rent, taken from it.', style: context.text.bodySmall),
          Gap.h16,
          SelectField<String>(label: 'City', hint: 'Where the tool is', value: _city, icon: AppIcons.city, items: {for (final c in cities) c: c}, onChanged: (v) => setState(() => _city = v)),
          Gap.h16,
          Row(children: [
            Expanded(child: Text('Units in stock', style: context.text.titleSmall)),
            Counter(value: _stock, min: 0, max: 999, onChanged: (v) => setState(() => _stock = v)),
          ]),
          const Divider(height: 28),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Listed in the market', style: context.text.titleSmall),
                Text('Turn off to hide it without deleting.', style: context.text.bodySmall),
              ]),
            ),
            Switch(value: _available, onChanged: (v) => setState(() => _available = v)),
          ]),
        ]),
      ),
      Gap.h16,
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Also sell in installments', style: context.text.titleSmall),
                Text('Customers pay monthly until it is theirs.', style: context.text.bodySmall),
              ]),
            ),
            Switch(value: _sells, onChanged: (v) => setState(() => _sells = v)),
          ]),
          if (_sells) ...[
            Gap.h16,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Field(
                    label: 'Full price',
                    hint: '24000',
                    prefixText: 'Rs  ',
                    controller: _price,
                    keyboardType: TextInputType.number,
                    formatters: Field.digits,
                    onChanged: (_) => setState(() {}),
                    validator: _sells ? positiveNumber('Enter the price') : null),
              ),
              Gap.w12,
              Expanded(
                child: Field(
                  label: 'Months',
                  hint: '6',
                  controller: _months,
                  keyboardType: TextInputType.number,
                  formatters: Field.digits,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (!_sells) return null;
                    final n = int.tryParse(v ?? '') ?? 0;
                    return n < 1 || n > 60 ? '1–60 months' : null;
                  },
                ),
              ),
            ]),
            if (_monthly > 0) ...[Gap.h12, Notice('Customers pay ${money(_monthly)} a month for ${_months.text} months.', tone: Tone.neutral)],
          ],
        ]),
      ),
      Gap.h16,
      Btn(editing ? 'Save changes' : 'List this tool', size: BtnSize.lg, expand: true, loading: _busy, onPressed: _save),
      if (editing) ...[Gap.h8, Btn('Delete tool', icon: AppIcons.trash, kind: BtnKind.danger, expand: true, onPressed: _busy ? null : _delete)],
    ]);

    return AppPage(
      title: editing ? 'Edit tool' : 'Add a tool',
      body: Form(key: _form, child: PageList(children: [TwoCol(main: main, side: side, sideWidth: 400)])),
    );
  }
}
