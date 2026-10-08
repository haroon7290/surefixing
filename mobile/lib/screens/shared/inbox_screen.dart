import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/message.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/async_list.dart';
import '../../widgets/states.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _list = GlobalKey<AsyncListState<Conversation>>();
  final _updates = RealtimeService.instance.on({'message:new', 'message:read'});

  Future<List<Conversation>> _load() async {
    final res = await ApiClient.getList('/api/messages');
    BadgeService.instance.refresh();
    return res.map(Conversation.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: AsyncList<Conversation>(
        key: _list,
        load: _load,
        reloadOn: _updates,
        padding: const EdgeInsets.symmetric(vertical: 8),
        spacing: 0,
        empty: EmptyState(
          icon: Icons.forum_outlined,
          title: 'No conversations yet',
          message: me.isTechnician
              ? 'Clients can message you once you quote on their job.'
              : 'Chat with technicians about a job once they quote or you hire them.',
        ),
        itemBuilder: (context, c, _) => _ConversationTile(
          c: c,
          meId: me.id,
          onTap: () async {
            await push(
              context,
              ChatScreen(jobId: c.jobId, otherId: c.other.id, otherName: c.other.name, otherAvatar: c.other.avatar, jobTitle: c.jobTitle),
            );
            _list.currentState?.reload();
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation c;
  final String meId;
  final VoidCallback onTap;
  const _ConversationTile({required this.c, required this.meId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final last = c.lastMessage;
    final unread = c.unread > 0;
    final preview = last.text.isNotEmpty ? last.text : (last.image.isNotEmpty ? '📷 Photo' : '');
    final cat = Catalog.service(c.jobCategory);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AppAvatar(name: c.other.name, url: c.other.avatar, size: 52, online: c.other.online),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(c.other.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700, fontSize: 15)),
                    ),
                    Text(Fmt.chatStamp(last.createdAt),
                        style: TextStyle(
                            fontSize: 12,
                            color: unread ? context.colors.primary : p.subtle,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(cat.icon, size: 13, color: cat.color),
                    const SizedBox(width: 4),
                    Expanded(
                        child:
                            Text(c.jobTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted))),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (last.senderId == meId) ...[
                      Icon(last.readAt != null ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 15, color: last.readAt != null ? p.info : p.subtle),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: unread ? context.colors.onSurface : p.muted, fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
                    ),
                    if (unread)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(10)),
                        child:
                            Text('${c.unread}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
