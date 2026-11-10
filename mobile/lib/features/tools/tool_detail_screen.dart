import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import '../account/report_sheet.dart';
import '../shell/shell.dart';
import '../technicians/tech_widgets.dart';
import '../wallet/wallet_screen.dart';
import 'tool_form_screen.dart';

/// A tool's page: photos, price, how handover works, and the request form
/// to rent it or buy it in installments.
class ToolDetailScreen extends StatefulWidget {
  final String toolId;
  const ToolDetailScreen({super.key, required this.toolId});

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  final _view = GlobalKey<AsyncViewState<Tool>>();
  final _address = TextEditingController(text: Session.instance.user?.address ?? '');
  final _note = TextEditingController();
  int _days = 3;
  DateTime _start = DateTime.now();
  String _fulfillment = 'pickup';
  int _photo = 0;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  bool _needLogin() {
    if (Session.instance.loggedIn) return false;
    toast('Sign in to rent or buy tools');
    SiteNav.go('login');
    return true;
  }

  Json? _handover() {
    if (_fulfillment == 'delivery' && _address.text.trim().isEmpty) {
      toast('Enter the address to deliver to');
      return null;
    }
    return {'fulfillment': _fulfillment, if (_fulfillment == 'delivery') 'deliveryAddress': _address.text.trim(), 'note': _note.text.trim()};
  }

  Future<void> _send(Future<dynamic> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      await call();
      Session.instance.refresh();
      toast(done, kind: ToastKind.success, actionLabel: 'View', onAction: () => openSection(navigatorKey.currentContext!, 'rentals'));
      if (!mounted) return;
      final seeRentals = await confirm(context, title: 'Request sent', message: 'The supplier will approve or decline it. You will get a notification either way.', confirmLabel: 'See my rentals', cancelLabel: 'Stay here', icon: AppIcons.success);
      if (seeRentals && mounted) openSection(context, 'rentals');
    } on ApiError catch (e) {
      e.insufficientFunds
          ? toast(e.message, kind: ToastKind.error, actionLabel: 'Add funds', onAction: () => openSection(navigatorKey.currentContext!, 'wallet'))
          : toastError(e);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rent(Tool tool) async {
    if (_needLogin()) return;
    final handover = _handover();
    if (handover == null) return;
    final cost = _days * tool.rentPricePerDay;
    final method = await choosePayment(
      context,
      title: 'Rent ${tool.name}',
      amount: cost,
      deposit: tool.deposit,
      confirmLabel: 'Send request',
      walletNote: 'The rental cost and deposit are held in escrow. If the supplier declines you are refunded in full; on return you get the deposit back, minus any late fee.',
      cashNote: 'You pay the supplier ${money(cost)}${tool.deposit > 0 ? ' plus the ${money(tool.deposit)} deposit' : ''} in person at handover.',
    );
    if (method == null) return;
    await _send(
      () => Api.post('/api/tools/${tool.id}/rent', {'days': _days, 'startDate': _start.toIso8601String(), 'paymentMethod': method, ...handover}),
      'Rental request sent',
    );
  }

  Future<void> _buy(Tool tool) async {
    if (_needLogin()) return;
    final handover = _handover();
    if (handover == null) return;
    final ok = await confirm(
      context,
      title: 'Buy in ${tool.installmentMonths} monthly payments?',
      message: '${money(tool.monthly)} a month, ${money(tool.purchasePrice)} in total. Once the supplier approves, pay each month from your wallet or in cash.',
      confirmLabel: 'Send request',
      icon: AppIcons.calendar,
    );
    if (ok) await _send(() => Api.post('/api/tools/${tool.id}/purchase', handover), 'Purchase request sent');
  }

  @override
  Widget build(BuildContext context) => AsyncView<Tool>(
        key: _view,
        load: () async => Tool.fromJson(await Api.map('/api/tools/${widget.toolId}')),
        loading: const AppPage(title: 'Tool', body: SkeletonList()),
        builder: (context, tool) => _body(context, tool),
      );

  Widget _body(BuildContext context, Tool tool) {
    final c = context.colors;
    final cat = toolCategory(tool.category);
    final me = Session.instance.user;
    final mine = me != null && tool.supplier.id == me.id;
    final canRequest = !mine && (me == null || me.isClient || me.isTechnician);
    final cost = _days * tool.rentPricePerDay;
    final end = _start.add(Duration(days: _days));

    final gallery = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      AspectRatio(
        aspectRatio: context.isWide ? 16 / 10 : 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.xl),
          child: Stack(fit: StackFit.expand, children: [
            GestureDetector(
              onTap: tool.images.isEmpty ? null : () => openGallery(context, tool.images, _photo),
              child: CoverImage(tool.images.isEmpty ? '' : tool.images[_photo.clamp(0, tool.images.length - 1)], category: cat, iconSize: 84, label: tool.name),
            ),
            Positioned(right: 12, top: 12, child: FavoriteButton(type: 'tool', id: tool.id, onImage: true)),
          ]),
        ),
      ),
      if (tool.images.length > 1) ...[
        Gap.h12,
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tool.images.length,
            separatorBuilder: (_, __) => Gap.w8,
            itemBuilder: (context, i) => Semantics(
              button: true,
              selected: i == _photo,
              label: 'Photo ${i + 1}',
              child: GestureDetector(
                onTap: () => setState(() => _photo = i),
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(R.md), border: Border.all(color: i == _photo ? c.ink : Colors.transparent, width: 2)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(R.sm), child: NetImage(tool.images[i], width: 64, height: 60)),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        Pill(cat.label, icon: cat.icon),
        Pill('Condition: ${toolConditions[tool.condition] ?? tool.condition}'),
        tool.rentable ? Pill('${tool.stock} available', tone: Tone.success, dot: true) : const Pill('Unavailable right now', tone: Tone.warning, dot: true),
      ]),
      Gap.h12,
      Text(tool.name, style: context.text.headlineLarge),
      Gap.h8,
      Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Rating(tool.rating, tool.ratingCount, size: 14),
        if (tool.city.isNotEmpty) Meta(AppIcons.pin, tool.city),
        if (tool.rentalsCount > 0) Meta(AppIcons.rentals, 'Rented ${plural(tool.rentalsCount, 'time')}'),
      ]),
      if (tool.description.isNotEmpty) ...[Gap.h16, Text(tool.description, style: context.text.bodyLarge!.copyWith(fontSize: 15.5))],
    ]);

    final supplier = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Supplier', style: context.text.bodySmall),
        Gap.h8,
        PersonRow(
          name: tool.supplier.name,
          image: tool.supplier.avatar,
          verified: tool.supplier.verified,
          subtitle: [if (tool.supplier.city.isNotEmpty) tool.supplier.city, 'On SureFix since ${shortDate(tool.supplier.createdAt)}'].join('  ·  '),
          size: 48,
          onTap: () => openTechnician(context, tool.supplier.id),
        ),
        if (canRequest && me != null) ...[
          Gap.h12,
          Btn('Ask the supplier a question', icon: AppIcons.chat, kind: BtnKind.outline, expand: true,
              onPressed: () => openChat(context, ChatTarget(toolId: tool.id, otherId: tool.supplier.id, otherName: tool.supplier.name, otherAvatar: tool.supplier.avatar, subject: tool.name))),
        ],
      ]),
    );

    final how = Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('How renting works', style: context.text.titleMedium),
        Gap.h8,
        for (final (icon, title, body) in [
          (AppIcons.store, 'Pickup or delivery', 'Collect from the supplier in ${tool.city.isEmpty ? 'their city' : tool.city}, or have it delivered. The exact address is shared once your request is approved.'),
          (AppIcons.shield, 'Refundable deposit', tool.deposit > 0 ? '${money(tool.deposit)} is held with your payment and returned when the tool is back.' : 'This tool needs no deposit.'),
          (AppIcons.timer, 'Late returns', 'Each late day costs one day of rent (${money(tool.rentPricePerDay)}), taken from the deposit.'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconTile(icon, size: 36),
              Gap.w12,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: context.text.titleSmall),
                  Text(body, style: context.text.bodySmall!.copyWith(color: c.body, fontSize: 13)),
                ]),
              ),
            ]),
          ),
      ]),
    );

    final reviews = tool.reviews.isEmpty
        ? null
        : Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Reviews (${tool.reviews.length})', style: context.text.titleMedium),
              for (final (i, r) in tool.reviews.indexed) ...[if (i > 0) const Divider(), ReviewTile(r)],
            ]),
          );

    final Widget booking;
    if (mine) {
      booking = Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('This is your listing', style: context.text.titleMedium),
          Gap.h4,
          Text('${money(tool.rentPricePerDay)} per day  ·  ${tool.stock} in stock', style: context.text.bodyMedium),
          Gap.h12,
          Btn('Edit tool', icon: AppIcons.edit, kind: BtnKind.dark, expand: true, onPressed: () async {
            await push(context, ToolFormScreen(tool: tool));
            _view.currentState?.reload();
          }),
        ]),
      );
    } else {
      booking = Panel(
        border: c.ink,
        borderWidth: 1.4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: money(tool.rentPricePerDay), style: context.text.headlineLarge),
            TextSpan(text: '  per day', style: context.text.bodyMedium),
          ])),
          if (tool.deposit > 0) Text('+ ${money(tool.deposit)} refundable deposit', style: context.text.bodySmall),
          if (canRequest) ...[
            Gap.h16,
            Row(children: [
              Expanded(child: Text('How long?', style: context.text.titleSmall)),
              Counter(value: _days, min: 1, max: 90, format: (d) => plural(d, 'day'), onChanged: (v) => setState(() => _days = v)),
            ]),
            Gap.h12,
            DateField(label: 'Starting', value: _start, last: DateTime.now().add(const Duration(days: 60)), onChanged: (d) => setState(() => _start = d ?? DateTime.now())),
            Gap.h4,
            Text('Return by ${longDate(end)}', style: context.text.bodySmall),
            Gap.h16,
            Segmented<String>(
              options: const {'pickup': 'I will pick up', 'delivery': 'Deliver to me'},
              icons: const {'pickup': AppIcons.store, 'delivery': AppIcons.truck},
              value: _fulfillment,
              onChanged: (v) => setState(() => _fulfillment = v),
            ),
            if (_fulfillment == 'delivery') ...[
              Gap.h12,
              Field(label: 'Delivery address', hint: 'House, street, area, city', controller: _address, icon: AppIcons.pin, maxLength: 300, maxLines: 2, minLines: 1),
            ],
            Gap.h12,
            Field(label: 'Note for the supplier', hint: 'e.g. I can collect after 5 pm', controller: _note, optional: true, maxLength: 500),
            Gap.h16,
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(R.md)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                KV('${money(tool.rentPricePerDay)} × ${plural(_days, 'day')}', money(cost)),
                if (tool.deposit > 0) KV('Deposit (refundable)', money(tool.deposit)),
                const Divider(),
                KV('Total today', money(cost + tool.deposit), strong: true),
              ]),
            ),
            Gap.h16,
            Btn(tool.rentable ? 'Request to rent' : 'Currently unavailable', size: BtnSize.lg, expand: true, loading: _busy, onPressed: tool.rentable ? () => _rent(tool) : null),
            if (tool.hasInstallments) ...[
              Gap.h12,
              Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or own it', style: context.text.bodySmall)), const Expanded(child: Divider())]),
              Gap.h12,
              Panel(
                color: c.brandSoft,
                border: Colors.transparent,
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Text('${money(tool.monthly)} a month for ${tool.installmentMonths} months', style: context.text.titleMedium!.copyWith(color: c.brandDeep)),
                  Text('Full price ${money(tool.purchasePrice)}. Pay monthly from your wallet or in cash.', style: context.text.bodySmall!.copyWith(color: c.brandDeep)),
                  Gap.h12,
                  Btn('Buy in installments', icon: AppIcons.calendar, kind: BtnKind.dark, expand: true, onPressed: tool.rentable && !_busy ? () => _buy(tool) : null),
                ]),
              ),
            ],
          ] else ...[
            Gap.h12,
            Notice(me.isSupplier ? 'Supplier accounts list tools. Use a customer account to rent.' : 'Admin view — renting is for customers and technicians.', tone: Tone.neutral),
          ],
        ]),
      );
    }

    Widget gap(Widget? w) => w == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 16), child: w);
    return AppPage(
      title: context.isWide ? 'Tool details' : 'Tool',
      actions: [
        if (me != null && !mine && !me.isAdmin)
          RoundBtn(AppIcons.reports, tooltip: 'Report this tool', size: 40, onPressed: () => showReportSheet(context, targetType: 'tool', targetId: tool.id, label: tool.name)),
      ],
      body: PageList(children: [
        TwoCol(
          sideWidth: 400,
          main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            gap(gallery),
            gap(info),
            if (!context.isWide) gap(booking),
            gap(supplier),
            gap(how),
            gap(reviews),
          ]),
          side: context.isWide ? booking : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}
