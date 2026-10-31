import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/tool.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navigation.dart';
import '../../services/site_nav.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/media.dart';
import '../../widgets/pills.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import 'chat_screen.dart';
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

  /// Visitors on the website are sent to log in before renting.
  bool _requireLogin() {
    if (AuthService.instance.loggedIn) return true;
    toast('Log in or create a free account to rent tools');
    SiteNav.go('login');
    return false;
  }

  Future<void> _rent() async {
    if (!_requireLogin()) return;
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
    if (!_requireLogin()) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PurchaseSheet(tool: _tool!),
    );
    if (ok == true) {
      _load();
      toast('Installment request sent — the supplier will confirm your plan',
          kind: ToastKind.success, action: SnackBarAction(label: 'My rentals', onPressed: () => push(context, const MyRentalsScreen())));
    }
  }

  void _messageSupplier(Tool t) {
    if (!_requireLogin()) return;
    push(
      context,
      ChatScreen(toolId: t.id, otherId: t.supplierId, otherName: t.supplier.name, otherAvatar: t.supplier.avatar, jobTitle: t.name),
    );
  }

  /// Who rents it out, how the customer gets the tool, and a way to ask.
  Widget _supplierCard(BuildContext context, Tool t, bool mine) {
    final p = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            AppAvatar(name: t.supplier.name, url: t.supplier.avatar, size: 46, verified: t.supplier.isVerified),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.supplier.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(t.supplier.city.isEmpty ? 'Tool supplier' : 'Tool supplier · ${t.supplier.city}',
                    style: TextStyle(color: p.muted, fontSize: 13)),
              ]),
            ),
            if (!mine && AuthService.instance.loggedIn)
              IconButton(
                tooltip: 'Report this listing',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => showReportSheet(context, targetType: 'tool', targetId: t.id, targetName: t.name),
              ),
          ]),
          const SizedBox(height: 12),
          InfoRow(
            icon: Icons.storefront_outlined,
            label: 'Pickup',
            value: t.city.isEmpty && t.supplier.city.isEmpty
                ? 'From the supplier\'s shop'
                : 'From their shop in ${t.city.isNotEmpty ? t.city : t.supplier.city}',
          ),
          const InfoRow(icon: Icons.local_shipping_outlined, label: 'Delivery', value: 'To your address, if you choose it'),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'The exact pickup address and phone number are shared as soon as the supplier approves your request.',
              style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
            ),
          ),
          if (!mine) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _messageSupplier(t),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text('Message ${t.supplier.name.isEmpty ? 'supplier' : t.supplier.name}'),
            ),
          ],
        ]),
      ),
    );
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
    if (context.isWide) return _wide(context, t, mine);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            actions: [
              if (!mine && AuthService.instance.loggedIn)
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
              const SectionHeader('Supplier & pickup', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
              _supplierCard(context, t, mine),
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

  /// Website layout: gallery beside the price/booking panel, details below.
  Widget _wide(BuildContext context, Tool t, bool mine) {
    final cat = Catalog.tool(t.category);
    final p = context.palette;
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WebPageTitle(t.name,
              subtitle: '${cat.label} · ${Catalog.toolConditions[t.condition] ?? t.condition}',
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 20)),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 6,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: GestureDetector(
                      onTap: t.images.isEmpty ? null : () => PhotoViewer.open(context, t.images, _photo),
                      child: NetImage(t.images.isEmpty ? '' : t.images[_photo.clamp(0, t.images.length - 1)], placeholder: cat),
                    ),
                  ),
                ),
                if (t.images.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    for (var i = 0; i < t.images.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _photo = i),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: i == _photo ? context.colors.primary : p.border, width: i == _photo ? 2 : 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: NetImage(t.images[i], width: 84, height: 64, placeholder: cat),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ],
                if (t.description.isNotEmpty) ...[
                  const SectionHeader('Description', padding: EdgeInsets.fromLTRB(4, 28, 0, 8)),
                  Text(t.description, style: context.text.bodyLarge),
                ],
                SectionHeader('Reviews (${t.reviews.length})', padding: const EdgeInsets.fromLTRB(4, 28, 0, 10)),
                if (t.reviews.isEmpty)
                  Text('No reviews yet — be the first to rent it.', style: TextStyle(color: p.muted))
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
            const SizedBox(width: 28),
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Pill(cat.label, color: cat.color, icon: cat.icon),
                        if (!t.inStock) Pill(t.available ? 'All rented out' : 'Unlisted', color: p.danger),
                        if (t.inStock) Pill('${t.stock} available', color: p.success),
                      ]),
                      const SizedBox(height: 14),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(Fmt.money(t.rentPricePerDay),
                            style: context.text.headlineMedium?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w800)),
                        Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(' / day', style: TextStyle(color: p.muted))),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        RatingLabel(rating: t.rating, count: t.ratingCount),
                        if (t.rentalsCount > 0) ...[
                          const SizedBox(width: 12),
                          Text('Rented ${Fmt.plural(t.rentalsCount, 'time')}', style: TextStyle(color: p.muted, fontSize: 13)),
                        ],
                      ]),
                      const Divider(height: 28),
                      if (t.deposit > 0) InfoRow(icon: Icons.shield_outlined, label: 'Refundable deposit', value: Fmt.money(t.deposit)),
                      if (t.purchasePrice > 0) InfoRow(icon: Icons.sell_outlined, label: 'Buy price', value: Fmt.money(t.purchasePrice)),
                      if (t.hasInstallments)
                        InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Installments',
                            value: '${t.installmentMonths} × ${Fmt.money(t.installmentMonthly)}'),
                      if (t.city.isNotEmpty) InfoRow(icon: Icons.place_outlined, label: 'Pickup city', value: t.city),
                      if (!mine) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: t.inStock ? _rent : null,
                          icon: const Icon(Icons.event_available_rounded),
                          label: Text(!t.inStock
                              ? 'Unavailable right now'
                              : AuthService.instance.loggedIn
                                  ? 'Rent this tool'
                                  : 'Log in to rent'),
                        ),
                        if (t.hasInstallments) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: t.inStock ? _buy : null,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Buy on installments'),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text('You won\'t be charged until the supplier approves.',
                            textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                _supplierCard(context, t, mine),
              ]),
            ),
          ]),
        ]),
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
  final _address = TextEditingController(text: AuthService.instance.user?.address ?? '');
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
    if (_fulfillment == 'delivery' && _address.text.trim().isEmpty) {
      toast('Enter the address to deliver to', kind: ToastKind.error);
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.post('/api/tools/${widget.tool.id}/rent', {
        'startDate': _range.start.toIso8601String(),
        'endDate': _range.end.toIso8601String(),
        'fulfillment': _fulfillment,
        if (_fulfillment == 'delivery') 'deliveryAddress': _address.text.trim(),
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
          const SizedBox(height: 10),
          HandoverFields(tool: t, fulfillment: _fulfillment, address: _address),
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

/// Explains the chosen handover: pickup (exact address after approval) or
/// delivery (address field, prefilled from the profile).
class HandoverFields extends StatelessWidget {
  final Tool tool;
  final String fulfillment;
  final TextEditingController address;
  const HandoverFields({super.key, required this.tool, required this.fulfillment, required this.address});

  @override
  Widget build(BuildContext context) {
    if (fulfillment == 'delivery') {
      return TextField(
        controller: address,
        minLines: 1,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Delivery address',
          hintText: 'House, street, area, city',
          prefixIcon: Icon(Icons.home_outlined),
        ),
      );
    }
    final city = tool.city.isNotEmpty ? tool.city : tool.supplier.city;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.palette.fill, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.storefront_outlined, size: 20, color: context.colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'You collect it from ${tool.supplier.name.isEmpty ? 'the supplier' : tool.supplier.name}${city.isEmpty ? '' : ' in $city'}. '
            'Their exact address and phone number appear in My rentals as soon as they approve.',
            style: TextStyle(color: context.palette.muted, fontSize: 13, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

class _PurchaseSheet extends StatefulWidget {
  final Tool tool;
  const _PurchaseSheet({required this.tool});

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  String _fulfillment = 'pickup';
  final _address = TextEditingController(text: AuthService.instance.user?.address ?? '');
  bool _sending = false;

  Future<void> _submit() async {
    if (_fulfillment == 'delivery' && _address.text.trim().isEmpty) {
      toast('Enter the address to deliver to', kind: ToastKind.error);
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiClient.post('/api/tools/${widget.tool.id}/purchase', {
        'fulfillment': _fulfillment,
        if (_fulfillment == 'delivery') 'deliveryAddress': _address.text.trim(),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Buy ${t.name} on installments', style: context.text.titleLarge),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.palette.fill, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              InfoRow(
                  icon: Icons.payments_outlined, label: 'Monthly', value: '${t.installmentMonths} × ${Fmt.money(t.installmentMonthly)}'),
              InfoRow(icon: Icons.sell_outlined, label: 'Total price', value: Fmt.money(t.purchasePrice)),
            ]),
          ),
          const SizedBox(height: 14),
          Text('How do you want to get it?', style: context.text.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pickup', icon: Icon(Icons.storefront_outlined), label: Text('Pickup')),
              ButtonSegment(value: 'delivery', icon: Icon(Icons.local_shipping_outlined), label: Text('Delivery')),
            ],
            selected: {_fulfillment},
            onSelectionChanged: (s) => setState(() => _fulfillment = s.first),
          ),
          const SizedBox(height: 10),
          HandoverFields(tool: t, fulfillment: _fulfillment, address: _address),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Text('Request installment plan'),
          ),
          const SizedBox(height: 6),
          Text('The supplier confirms the plan and arranges the handover with you.',
              textAlign: TextAlign.center, style: TextStyle(color: context.palette.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}
