import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';
import 'chat_screen.dart';

/// All conversations. On wide windows the chat opens beside the list.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _view = GlobalKey<AsyncViewState<List<Conversation>>>();
  Conversation? _open;

  static String _key(Conversation c) => '${c.isTool ? 'tool:${c.toolId}' : c.jobId}|${c.other.id}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = context.isWide;
    return AppPage(
      title: 'Messages',
      subtitle: 'Conversations about your jobs and rentals.',
      body: AsyncView<List<Conversation>>(
        key: _view,
        load: () async => (await Api.list('/api/messages')).map(Conversation.fromJson).toList(),
        events: Live.messages,
        builder: (context, items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: AppIcons.chat,
              title: 'No messages yet',
              message: switch (Session.instance.role) {
                'client' => 'Message a technician from one of their quotes, or a supplier from a tool page.',
                'technician' => 'Chats with clients start from a job you quoted on or were hired for.',
                _ => 'Customers can message you from your tool pages.',
              },
            );
          }

          Widget row(Conversation conv) {
            final selected = wide && _open != null && _key(_open!) == _key(conv);
            final mine = conv.last.senderId == Session.instance.user?.id;
            final preview = conv.last.text.isEmpty ? 'Sent a photo' : conv.last.text;
            return Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () async {
                  if (wide) {
                    setState(() => _open = conv);
                  } else {
                    await push(context, ChatScreen(target: conv.target));
                    _view.currentState?.reload();
                  }
                  Badges.instance.refresh();
                },
                child: Container(
                  color: selected ? c.sunken : null,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Avatar(name: conv.other.name, image: conv.other.avatar, size: 50, online: conv.other.online),
                    Gap.w12,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Expanded(child: Text(conv.other.name, style: context.text.titleSmall!.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text(timeAgo(conv.last.createdAt), style: context.text.bodySmall!.copyWith(fontSize: 11.5, color: conv.unread > 0 ? c.brandDeep : c.muted)),
                        ]),
                        Gap.h2,
                        Row(children: [
                          Icon(conv.isTool ? AppIcons.tools : AppIcons.jobs, size: 12, color: c.muted),
                          Gap.w4,
                          Expanded(child: Text(conv.title, style: context.text.bodySmall!.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                        Gap.h4,
                        Row(children: [
                          Expanded(
                            child: Text(
                              mine ? 'You: $preview' : preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium!.copyWith(fontSize: 13.5, color: conv.unread > 0 ? c.ink : c.body, fontWeight: conv.unread > 0 ? FontWeight.w700 : FontWeight.w500),
                            ),
                          ),
                          if (conv.unread > 0) ...[Gap.w8, CountBadge(conv.unread)],
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          }

          final list = Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < items.length; i++) ...[if (i > 0) Divider(indent: 76, color: c.line), row(items[i])],
            ]),
          );

          if (!wide) return PageList(onRefresh: () => _view.currentState!.reload(), children: [list]);

          final open = _open;
          return PagePad(
            bottom: 24,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 380, child: SingleChildScrollView(child: list)),
              Gap.w16,
              Expanded(
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: open == null
                      ? const EmptyState(icon: AppIcons.chat, title: 'Pick a conversation', message: 'Choose someone on the left to read and reply.')
                      : Column(children: [
                          Expanded(child: ChatView(key: ValueKey(_key(open)), target: open.target, showHeader: true)),
                        ]),
                ),
              ),
              if (open != null) ...[
                Gap.w16,
                SizedBox(
                  width: 44,
                  child: Column(children: [
                    RoundBtn(open.isTool ? AppIcons.tools : AppIcons.jobs, tooltip: open.isTool ? 'Open tool' : 'Open job', onPressed: () => open.isTool ? openTool(context, open.toolId) : openJob(context, open.jobId)),
                  ]),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }
}
