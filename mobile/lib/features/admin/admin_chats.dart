import 'dart:async';

import 'package:flutter/material.dart';

import '../../kit.dart';
import '../../routes.dart';

/// A conversation between two users about a job or a tool, as admins see it.
class AdminConversation {
  final bool isTool;
  final String jobId;
  final String toolId;
  final String subject;
  final int jobNumber;
  final String jobStatus;
  final User a;
  final User b;
  final int count;
  final Message last;
  const AdminConversation({
    required this.isTool,
    this.jobId = '',
    this.toolId = '',
    this.subject = '',
    this.jobNumber = 0,
    this.jobStatus = '',
    required this.a,
    required this.b,
    this.count = 0,
    required this.last,
  });

  factory AdminConversation.fromJson(Json j) => AdminConversation(
        isTool: j['kind'] == 'tool',
        jobId: idOf(j['jobId']),
        toolId: idOf(j['toolId']),
        subject: str(j['subject']),
        jobNumber: integer(j['jobNumber']),
        jobStatus: str(j['jobStatus']),
        a: User.fromJson(asJson(j['a'])),
        b: User.fromJson(asJson(j['b'])),
        count: integer(j['count']),
        last: Message.fromJson(asJson(j['lastMessage'])),
      );

  Map<String, dynamic> get query => {if (isTool) 'tool': toolId else 'job': jobId, 'a': a.id, 'b': b.id};
}

/// Every chat between users, newest first, read-only: what was agreed, for
/// disputes and reports.
class AdminChatsView extends StatefulWidget {
  const AdminChatsView({super.key});

  @override
  State<AdminChatsView> createState() => _AdminChatsViewState();
}

class _AdminChatsViewState extends State<AdminChatsView> {
  final _view = GlobalKey<AsyncViewState<List<AdminConversation>>>();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PagePad(
        child: SearchBox(
          hint: 'Search by name, job, tool or a job number like SF-1024',
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
          },
        ),
      ),
      Expanded(
        child: AsyncView<List<AdminConversation>>(
          key: _view,
          token: _query,
          load: () async => (await Api.list('/api/admin/conversations', query: {'q': _query})).map(AdminConversation.fromJson).toList(),
          events: Live.messages,
          builder: (context, items) => items.isEmpty
              ? EmptyState(icon: AppIcons.chat, title: _query.isEmpty ? 'No chats yet' : 'No chats match', message: 'Chats between customers, technicians and suppliers appear here.')
              : PageList(
                  onRefresh: () => _view.currentState!.reload(),
                  children: [
                    const Notice('Read-only. Reading a chat does not mark it as read for the people in it.', tone: Tone.neutral, icon: AppIcons.eye),
                    Gap.h12,
                    Panel(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) Divider(indent: 76, color: c.line),
                          _row(context, items[i]),
                        ],
                      ]),
                    ),
                  ],
                ),
        ),
      ),
    ]);
  }

  Widget _row(BuildContext context, AdminConversation conv) {
    final c = context.colors;
    final preview = conv.last.text.isEmpty ? 'Sent a photo' : conv.last.text;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => push(context, AdminThreadScreen(conversation: conv)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(children: [
                Avatar(name: conv.a.name, image: conv.a.avatar, size: 36),
                Positioned(right: 0, bottom: 0, child: Avatar(name: conv.b.name, image: conv.b.avatar, size: 32)),
              ]),
            ),
            Gap.w12,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                    child: Text('${conv.a.name}  ↔  ${conv.b.name}', style: context.text.titleSmall!.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(timeAgo(conv.last.createdAt), style: context.text.bodySmall!.copyWith(fontSize: 11.5)),
                ]),
                Gap.h2,
                Row(children: [
                  Icon(conv.isTool ? AppIcons.tools : AppIcons.jobs, size: 12, color: c.muted),
                  Gap.w4,
                  Expanded(
                    child: Text(conv.jobNumber > 0 ? 'SF-${conv.jobNumber} · ${conv.subject}' : conv.subject,
                        style: context.text.bodySmall!.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
                Gap.h4,
                Row(children: [
                  Expanded(
                    child: Text('${conv.last.senderName.split(' ').first}: $preview',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium!.copyWith(fontSize: 13.5, color: c.body)),
                  ),
                  Gap.w8,
                  Pill(plural(conv.count, 'message')),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One conversation between two users, read-only, with shortcuts to step in
/// as SureFix Support.
class AdminThreadScreen extends StatelessWidget {
  final AdminConversation conversation;
  const AdminThreadScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final conv = conversation;
    final c = context.colors;
    final about = conv.isTool ? 'Tool: ${conv.subject}' : (conv.jobNumber > 0 ? 'Job SF-${conv.jobNumber}: ${conv.subject}' : 'Job: ${conv.subject}');
    return AppPage(
      title: '${conv.a.firstName} & ${conv.b.firstName}',
      subtitle: about,
      maxWidth: 860,
      body: AsyncView<List<Message>>(
        load: () async => (await Api.list('/api/admin/conversations/thread', query: conv.query)).map(Message.fromJson).toList(),
        builder: (context, msgs) => PageList(children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            Btn('Message ${conv.a.firstName} as SureFix',
                icon: AppIcons.chat,
                kind: BtnKind.outline,
                size: BtnSize.sm,
                onPressed: () => openSupportChat(context, userId: conv.a.id, name: conv.a.name, avatar: conv.a.avatar, about: about)),
            Btn('Message ${conv.b.firstName} as SureFix',
                icon: AppIcons.chat,
                kind: BtnKind.outline,
                size: BtnSize.sm,
                onPressed: () => openSupportChat(context, userId: conv.b.id, name: conv.b.name, avatar: conv.b.avatar, about: about)),
            if (conv.jobId.isNotEmpty) Btn('Open job', kind: BtnKind.dark, size: BtnSize.sm, trailing: AppIcons.arrowUpRight, onPressed: () => openJob(context, conv.jobId)),
            if (conv.toolId.isNotEmpty) Btn('Open tool', kind: BtnKind.dark, size: BtnSize.sm, trailing: AppIcons.arrowUpRight, onPressed: () => openTool(context, conv.toolId)),
          ]),
          Gap.h16,
          if (msgs.isEmpty) const EmptyState(icon: AppIcons.chat, title: 'No messages', compact: true),
          for (final m in msgs) _ReadOnlyBubble(m, right: m.senderId == conv.b.id),
          Gap.h8,
          Center(child: Text('Read-only: people in this chat are not told you viewed it.', style: context.text.bodySmall!.copyWith(color: c.muted))),
        ]),
      ),
    );
  }
}

class _ReadOnlyBubble extends StatelessWidget {
  final Message m;
  final bool right;
  const _ReadOnlyBubble(this.m, {required this.right});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(m.senderName, style: context.text.bodySmall!.copyWith(fontWeight: FontWeight.w700)),
            Gap.h2,
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: right ? c.sunken : c.surface,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (m.image.isNotEmpty) GestureDetector(onTap: () => openGallery(context, [m.image]), child: NetImage(m.image, width: 240, height: 180)),
                if (m.text.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 9, 14, 10), child: Text(m.text, style: context.text.bodyLarge!.copyWith(fontSize: 15))),
              ]),
            ),
            Gap.h2,
            Text('${shortDate(m.createdAt)} · ${clock(m.createdAt)}${m.read ? '  ·  Read' : ''}', style: context.text.bodySmall!.copyWith(fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
