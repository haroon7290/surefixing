import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/media.dart';
import '../../widgets/pills.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import 'my_rentals_screen.dart';
import 'report_sheet.dart';

class ToolDetailScreen extends StatefulWidget {
  final String toolId;
  const ToolDetailScreen({super.key, required this.toolId});

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  Tool? _tool;
  Object? _error;
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = Tool.fromJson(await ApiClient.getMap('/api/tools/${widget.toolId}'));
      if (mounted) {
        setState(() {
          _tool = t;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _rent() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RentSheet(tool: _tool!),
    );
    if (ok == true) {
      _load();
      if (mounted) {
        toast('Request sent — the supplier will confirm shortly',
            kind: ToastKind.success, action: SnackBarAction(label: 'My rentals', onPressed: () => push(context, const MyRentalsScreen())));
      }
    }
  }

  Future<void> _buy() async {
    final t = _tool!;
    final ok = await confirmDialog(
      context,
      title: 'Buy on installments',
      message:
          '${t.installmentMonths} monthly payments of ${Fmt.money(t.installmentMonthly)}\nTotal ${Fmt.money(t.purchasePrice)}.\n\nThe supplier will confirm your plan.',
      confirm: 'Request plan',
    );
    if (!ok) return;
    try {
      await ApiClient.post('/api/tools/${t.id}/purchase');
      toast('Installment request sent', kind: ToastKind.success);
      _load();
    } catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tool;
    if (t == null) {
      return Scaffold(
          appBar: AppBar(), body: _error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList(count: 3));
    }
    final cat = Catalog.tool(t.category);
    final mine = t.supplierId == AuthService.instance.user?.id;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            actions: [
              if (!mine)
                IconButton(
                  tooltip: 'Report',
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => showReportSheet(context, targetType: 'tool', targetId: t.id, targetName: t.name),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  t.images.isEmpty
                      ? NetImage('', placeholder: cat)
                      : PageView.builder(
                          itemCount: t.images.length,
                          onPageChanged: (i) => setState(() => _photo = i),
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => PhotoViewer.open(context, t.images, i),
                            child: NetImage(t.images[i], placeholder: cat),
                          ),
                        ),
                  if (t.images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          t.images.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _photo ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: i == _photo ? 1 : 0.6), borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            sliver: SliverList.list(children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill(cat.label, color: cat.color, icon: cat.icon),
                Pill(Catalog.toolConditions[t.condition] ?? t.condition, color: context.palette.muted),
                if (!t.inStock) Pill(t.available ? 'All rented out' : 'Unlisted', color: context.palette.danger),
                if (t.inStock) Pill('${t.stock} available', color: context.palette.success),
              ]),
              const SizedBox(height: 12),
              Text(t.name, style: context.text.headlineSmall),
              const SizedBox(height: 6),
              Row(children: [
                RatingLabel(rating: t.rating, count: t.ratingCount),
                if (t.rentalsCount > 0) ...[
                  const SizedBox(width: 12),
                  Text('Rented ${Fmt.plural(t.rentalsCount, 'time')}', style: TextStyle(color: context.palette.muted, fontSize: 13)),
                ],
              ]),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(Fmt.money(t.rentPricePerDay),
                          style: context.text.headlineSmall?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w800)),
                      Padding(
                          padding: const EdgeInsets.only(bottom: 3), child: Text(' / day', style: TextStyle(color: context.palette.muted))),
                    ]),
                    const SizedBox(height: 8),
                    if (t.deposit > 0) InfoRow(icon: Icons.shield_outlined, label: 'Refundable deposit', value: Fmt.money(t.deposit)),
                    if (t.purchasePrice > 0) InfoRow(icon: Icons.sell_outlined, label: 'Buy price', value: Fmt.money(t.purchasePrice)),
                    if (t.hasInstallments)
                      InfoRow(
                          icon: Icons.payments_outlined,
                          label: 'Installments',
                          value: '${t.installmentMonths} × ${Fmt.money(t.installmentMonthly)}'),
                    if (t.city.isNotEmpty) InfoRow(icon: Icons.place_outlined, label: 'Pickup city', value: t.city),
                  ]),
                ),
              ),
              if (t.description.isNotEmpty) ...[
                const SectionHeader('Description', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
                Text(t.description, style: context.text.bodyMedium),
              ],
              const SectionHeader('Supplier', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: AppAvatar(name: t.supplier.name, url: t.supplier.avatar, size: 44, verified: t.supplier.isVerified),
                  title: Text(t.supplier.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(t.supplier.city.isEmpty ? 'Tool supplier' : 'Tool supplier · ${t.supplier.city}'),
                ),
              ),
              SectionHeader('Reviews (${t.reviews.length})', padding: const EdgeInsets.fromLTRB(4, 20, 0, 8)),
              if (t.reviews.isEmpty)
                Text('No reviews yet — be the first to rent it.', style: TextStyle(color: context.palette.muted))
              else
                for (final r in t.reviews)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            AppAvatar(name: r.renterName, url: r.renterAvatar, size: 30),
                            const SizedBox(width: 10),
                            Expanded(child: Text(r.renterName, style: const TextStyle(fontWeight: FontWeight.w700))),
                            RatingStars(value: r.rating, size: 14),
                          ]),
                          if (r.review.isNotEmpty) ...[const SizedBox(height: 8), Text(r.review)],
                        ]),
                      ),
                    ),
                  ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: mine
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  if (t.hasInstallments) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                          onPressed: t.inStock ? _buy : null, icon: const Icon(Icons.payments_outlined), label: const Text('Installments')),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: t.inStock ? _rent : null,
                      icon: const Icon(Icons.event_available_rounded),
                      label: Text(t.inStock ? 'Rent' : 'Unavailable'),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}

class _RentSheet extends StatefulWidget {
  final Tool tool;
  const _RentSheet({required this.tool});

  @override
  State<_RentSheet> createState() => _RentSheetState();
}

class _RentSheetState extends State<_RentSheet> {
  late DateTimeRange _range;
  String _fulfillment = 'pickup';
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    _range = DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
  }

  int get _days => _range.end.difference(_range.start).inDays.clamp(1, 90);

  Future<void> _pick() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 120)),
      initialDateRange: _range,
      helpText: 'Rental period',
    );
    if (r != null) {
      setState(() => _range = r.end.isAfter(r.start) ? r : DateTimeRange(start: r.start, end: r.start.add(const Duration(days: 1))));
    }
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ApiClient.post('/api/tools/${widget.tool.id}/rent', {
        'startDate': _range.start.toIso8601String(),
        'endDate': _range.end.toIso8601String(),
        'fulfillment': _fulfillment,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      toastError(e);
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tool;
    final total = _days * t.rentPricePerDay;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rent ${t.name}', style: context.text.titleLarge),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pick,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Dates', prefixIcon: Icon(Icons.date_range_rounded)),
              child:
                  Text('${Fmt.weekday(_range.start)}  →  ${Fmt.weekday(_range.end)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pickup', icon: Icon(Icons.storefront_outlined), label: Text('Pickup')),
              ButtonSegment(value: 'delivery', icon: Icon(Icons.local_shipping_outlined), label: Text('Delivery')),
            ],
            selected: {_fulfillment},
            onSelectionChanged: (s) => setState(() => _fulfillment = s.first),
          ),
          const SizedBox(height: 14),
          TextField(controller: _note, decoration: const InputDecoration(hintText: 'Note for the supplier (optional)')),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.palette.fill, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              _row(context, '${Fmt.money(t.rentPricePerDay)} × ${Fmt.plural(_days, 'day')}', Fmt.money(total)),
              if (t.deposit > 0) _row(context, 'Refundable deposit', Fmt.money(t.deposit)),
              const Divider(height: 18),
              _row(context, 'Due at ${_fulfillment == 'delivery' ? 'delivery' : 'pickup'}', Fmt.money(total + t.deposit), bold: true),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Text('Send rental request'),
          ),
          const SizedBox(height: 6),
          Text('You won\'t be charged until the supplier approves.',
              textAlign: TextAlign.center, style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String l, String r, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(l,
                  style: TextStyle(color: bold ? null : context.palette.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(r, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}
