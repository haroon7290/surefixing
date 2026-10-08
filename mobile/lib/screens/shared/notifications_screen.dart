import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../services/api_client.dart';
import '../../services/badge_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/states.dart';
import '../routes.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  Object? _error;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.on({'notification'}).listen((e) {
      if (!mounted || _items == null) return;
      setState(() => _items = [AppNotification.fromJson(e.data), ..._items!]);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    BadgeService.instance.refresh();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.getList('/api/users/me/notifications');
      if (mounted) {
        setState(() {
          _items = res.map(AppNotification.fromJson).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _readAll() async {
    try {
      await ApiClient.post('/api/users/me/notifications/read-all');
      setState(() => _items = _items?.map((n) => n.asRead()).toList());
      BadgeService.instance.refresh();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (n.unread) {
      setState(() => _items = _items!.map((x) => x.id == n.id ? x.asRead() : x).toList());
      ApiClient.post('/api/users/me/notifications/${n.id}/read').catchError((_) => null);
    }
    openTarget(context, type: n.type, data: n.data);
  }

  (IconData, Color) _style(BuildContext context, String type) {
    final p = context.palette;
    return switch (type) {
      'bid' => (Icons.request_quote_rounded, context.colors.primary),
      'request' => (Icons.person_pin_rounded, const Color(0xFF7A5AF8)),
      'job_status' => (Icons.work_rounded, p.warning),
      'review' => (Icons.star_rounded, p.star),
      'rental' => (Icons.handyman_rounded, Brand.accent),
      'kyc' => (Icons.verified_user_rounded, p.success),
      'report' => (Icons.flag_rounded, p.danger),
      'message' => (Icons.chat_bubble_rounded, p.info),
      _ => (Icons.notifications_rounded, p.muted),
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final hasUnread = items?.any((n) => n.unread) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [if (hasUnread) TextButton(onPressed: _readAll, child: const Text('Mark all read'))],
      ),
      body: items == null
          ? (_error != null ? ErrorView(message: _error.toString(), onRetry: _load) : const SkeletonList())
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 80),
                      EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'You\'re all caught up',
                          message: 'Quotes, hires, rentals and reviews will show up here.'),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final n = items[i];
                        final header = i == 0 || Fmt.dayLabel(items[i - 1].createdAt) != Fmt.dayLabel(n.createdAt);
                        final (icon, color) = _style(context, n.type);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (header)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                                child: Text(Fmt.dayLabel(n.createdAt),
                                    style: TextStyle(fontWeight: FontWeight.w700, color: context.palette.muted, fontSize: 13)),
                              ),
                            Material(
                              color: n.unread ? context.colors.primary.withValues(alpha: context.isDark ? 0.1 : 0.04) : Colors.transparent,
                              child: InkWell(
                                onTap: () => _open(n),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
                                        child: Icon(icon, color: color, size: 21),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(n.title, style: TextStyle(fontWeight: n.unread ? FontWeight.w800 : FontWeight.w600)),
                                            if (n.body.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(n.body, style: TextStyle(color: context.palette.muted, fontSize: 13.5)),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(Fmt.ago(n.createdAt), style: TextStyle(color: context.palette.subtle, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      if (n.unread)
                                        Container(
                                          margin: const EdgeInsets.only(top: 6, left: 8),
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
    );
  }
}
