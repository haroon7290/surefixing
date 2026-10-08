import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/rental.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand.dart';
import '../../widgets/cards.dart';
import '../../widgets/states.dart';
import '../../widgets/visuals.dart';
import '../shared/kyc_screen.dart';
import '../shared/notifications_screen.dart';
import '../shells.dart';
import 'rental_actions.dart';
import 'tool_form_screen.dart';

class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  Map<String, dynamic>? _summary;
  List<Rental>? _pending;
  List<Rental>? _overdue;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.on({'rental:new', 'rental:update'}).listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.getMap('/api/users/me/summary'),
        ApiClient.getList('/api/rentals', query: {'as': 'supplier', 'status': 'requested'}),
        ApiClient.getList('/api/rentals', query: {'as': 'supplier', 'status': 'active'}),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _pending = (results[1] as List<Map<String, dynamic>>).map(Rental.fromJson).toList();
        _overdue = (results[2] as List<Map<String, dynamic>>).map(Rental.fromJson).where((r) => r.overdue).toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _summary ??= {};
          _pending ??= [];
          _overdue ??= [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.user!;
    final s = _summary;
    final rentals = (s?['rentals'] as Map?) ?? {};
    final p = context.palette;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: const BoxDecoration(gradient: heroGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      AppAvatar(name: me.name, url: me.avatar, size: 44, verified: me.isVerified),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(me.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
                          Text('Supplier dashboard', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                        ]),
                      ),
                      IconButton(
                        color: Colors.white,
                        tooltip: 'Notifications',
                        onPressed: () async {
                          await push(context, const NotificationsScreen());
                          BadgeService.instance.refresh();
                        },
                        icon: BadgeIcon(icon: Icons.notifications_none_rounded, count: BadgeService.instance.unreadNotifications),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Text('Rental revenue', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(s == null ? '—' : Fmt.money(s['revenue'] ?? 0),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: [
                  StatTile(
                      icon: Icons.handyman_rounded,
                      value: '${s?['tools'] ?? '—'}',
                      label: 'Tools',
                      onTap: () => HomeShell.goTo(context, 1)),
                  StatTile(
                      icon: Icons.mark_email_unread_rounded,
                      value: '${rentals['requested'] ?? 0}',
                      label: 'Requests',
                      color: Brand.accent,
                      onTap: () => HomeShell.goTo(context, 2)),
                  StatTile(
                      icon: Icons.timelapse_rounded,
                      value: '${rentals['active'] ?? 0}',
                      label: 'On rent',
                      color: p.success,
                      onTap: () => HomeShell.goTo(context, 2)),
                ],
              ),
            ),
            if (!me.isVerified)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Icon(Icons.verified_user_rounded, color: p.info),
                    title: Text(me.kycStatus == 'pending' ? 'Verification in review' : 'Verify your business',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Verified suppliers get a badge customers trust.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => push(context, const KycScreen()),
                  ),
                ),
              ),
            if ((_overdue ?? []).isNotEmpty) ...[
              SectionHeader('Overdue returns (${_overdue!.length})'),
              for (final r in _overdue!)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: RentalCard(rental: r, perspective: 'supplier', actions: rentalActions(context, r, _load)),
                ),
            ],
            SectionHeader('Requests waiting for you', actionLabel: 'All requests', onAction: () => HomeShell.goTo(context, 2)),
            if (_pending == null)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkeletonCard())
            else if (_pending!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.inbox_outlined,
                    title: 'No pending requests',
                    message: 'List more tools to get more rentals.',
                    actionLabel: 'Add a tool',
                    onAction: () async {
                      await push(context, const ToolFormScreen());
                      _load();
                    },
                  ),
                ),
              )
            else
              for (final r in _pending!)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: RentalCard(rental: r, perspective: 'supplier', actions: rentalActions(context, r, _load)),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
