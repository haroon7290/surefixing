import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';

/// Everything SureFix has told the user, newest first.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _view = GlobalKey<AsyncViewState<List<AppNotification>>>();

  static (IconData, Tone) _look(String type) => switch (type) {
        'bid' => (AppIcons.tag, Tone.info),
        'request' => (AppIcons.bolt, Tone.brand),
        'job_status' => (AppIcons.jobs, Tone.brand),
        'review' => (AppIcons.starFill, Tone.warning),
        'rental' => (AppIcons.tools, Tone.info),
        'kyc' => (AppIcons.verify, Tone.success),
        'report' => (AppIcons.reports, Tone.neutral),
        'account' => (AppIcons.user, Tone.neutral),
        _ => (AppIcons.bell, Tone.neutral),
      };

  Future<void> _readAll() async {
    try {
      await Api.post('/api/users/me/notifications/read-all');
      Badges.instance.refresh();
      _view.currentState?.reload();
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      Api.post('/api/users/me/notifications/${n.id}/read').then((_) {
        Badges.instance.refresh();
        _view.currentState?.reload();
      }).catchError((_) {});
    }
    openTarget(context, type: n.type, data: n.data);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPage(
      title: 'Notifications',
      maxWidth: 820,
      actions: [Btn('Mark all read', kind: BtnKind.soft, size: BtnSize.sm, icon: AppIcons.check, onPressed: _readAll)],
      body: AsyncView<List<AppNotification>>(
        key: _view,
        load: () async => (await Api.list('/api/users/me/notifications', query: {'limit': 80})).map(AppNotification.fromJson).toList(),
        events: Live.notifications,
        builder: (context, items) => items.isEmpty
            ? const EmptyState(icon: AppIcons.bell, title: 'You are all caught up', message: 'Quotes, job updates, payments and reviews will show up here.')
            : PageList(
                onRefresh: () => _view.currentState!.reload(),
                children: [
                  Panel(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) Divider(indent: 68, color: c.line),
                        Semantics(
                          button: true,
                          child: InkWell(
                            onTap: () => _open(items[i]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                IconTile(_look(items[i].type).$1, tone: _look(items[i].type).$2, size: 40, round: true),
                                Gap.w12,
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                    Text(items[i].title, style: context.text.titleSmall!.copyWith(fontWeight: items[i].read ? FontWeight.w600 : FontWeight.w800)),
                                    if (items[i].body.isNotEmpty) ...[Gap.h2, Text(items[i].body, style: context.text.bodyMedium!.copyWith(fontSize: 13.5), maxLines: 3, overflow: TextOverflow.ellipsis)],
                                    Gap.h4,
                                    Text(timeAgo(items[i].createdAt), style: context.text.bodySmall!.copyWith(fontSize: 11.5)),
                                  ]),
                                ),
                                if (!items[i].read) Padding(padding: const EdgeInsets.only(top: 6, left: 8), child: Container(width: 9, height: 9, decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle))),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ],
              ),
      ),
    );
  }
}
