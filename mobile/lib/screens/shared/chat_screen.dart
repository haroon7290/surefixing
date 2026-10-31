import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/message.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/navigation.dart';
import '../../services/realtime_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/media.dart';
import '../../widgets/states.dart';
import '../client/job_detail_client.dart';
import '../technician/tech_job_detail.dart';
import 'tool_detail_screen.dart';

/// A conversation about a job (client ↔ technician, pass [jobId]) or about
/// a tool (customer ↔ supplier, pass [toolId]).
class ChatScreen extends StatefulWidget {
  final String jobId;
  final String toolId;
  final String otherId;
  final String otherName;
  final String otherAvatar;

  /// What the chat is about: the job title or the tool name.
  final String jobTitle;

  const ChatScreen({
    super.key,
    this.jobId = '',
    this.toolId = '',
    required this.otherId,
    required this.otherName,
    this.otherAvatar = '',
    this.jobTitle = '',
  }) : assert(jobId != '' || toolId != '', 'A chat is about a job or a tool');

  static String? _active;

  /// Used by the global toast handler to stay quiet for the open chat.
  /// [thread] is a job id or 'tool:<toolId>'.
  static bool isOpen(String thread, String otherId) => _active == '$thread:$otherId';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage>? _messages;
  Object? _error;
  bool _sending = false;
  bool _otherTyping = false;
  Timer? _typingTimer;
  Timer? _poll;
  DateTime _lastTypingEmit = DateTime(2000);
  StreamSubscription? _sub;

  String get _me => AuthService.instance.user!.id;

  bool get _isTool => widget.toolId.isNotEmpty;
  String get _thread => _isTool ? 'tool:${widget.toolId}' : widget.jobId;
  String get _base => _isTool ? '/api/messages/tool/${widget.toolId}' : '/api/messages/${widget.jobId}';

  @override
  void initState() {
    super.initState();
    ChatScreen._active = '$_thread:${widget.otherId}';
    _load();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
    _sub = RealtimeService.instance.events.listen(_onEvent);
  }

  @override
  void dispose() {
    if (ChatScreen._active == '$_thread:${widget.otherId}') ChatScreen._active = null;
    _sub?.cancel();
    _poll?.cancel();
    _typingTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    BadgeService.instance.refresh();
    super.dispose();
  }

  void _onEvent(RealtimeEvent e) {
    if (!mounted) return;
    final thread = (e.data['thread'] ?? e.jobId).toString();
    if (e.name == 'message:new' && thread == _thread) {
      final m = ChatMessage.fromJson(e.data);
      final inThread = (m.senderId == widget.otherId && m.recipientId == _me) || (m.senderId == _me && m.recipientId == widget.otherId);
      if (!inThread) return;
      _append(m);
      if (m.senderId == widget.otherId) {
        setState(() => _otherTyping = false);
        ApiClient.post('$_base/read?with=${widget.otherId}').catchError((_) => null);
      }
    } else if (e.name == 'message:read' && thread == _thread && e.data['by'] == widget.otherId) {
      setState(() => _messages = _messages?.map((m) => m.senderId == _me ? m.markRead() : m).toList());
    } else if (e.name == 'typing' && e.data['jobId'] == _thread && e.data['from'] == widget.otherId) {
      _typingTimer?.cancel();
      setState(() => _otherTyping = e.data['typing'] != false);
      _typingTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _otherTyping = false);
      });
    }
  }

  void _append(ChatMessage m) {
    final list = _messages ?? [];
    if (list.any((x) => x.id == m.id)) return;
    setState(() => _messages = [...list, m]);
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final res = await ApiClient.getList(_base, query: {'with': widget.otherId});
      if (!mounted) return;
      setState(() {
        _messages = res.map(ChatMessage.fromJson).toList();
        _error = null;
      });
    } catch (e) {
      if (!silent && mounted) setState(() => _error = e);
    }
  }

  void _onTyping(String _) {
    final now = DateTime.now();
    if (now.difference(_lastTypingEmit) < const Duration(seconds: 2)) return;
    _lastTypingEmit = now;
    RealtimeService.instance.emit('typing', {'to': widget.otherId, 'jobId': _thread, 'typing': true});
  }

  Future<void> _send({XFile? image}) async {
    final text = _text.text.trim();
    if (text.isEmpty && image == null) return;
    setState(() => _sending = true);
    try {
      final dynamic res = image == null
          ? await ApiClient.post(_base, {'text': text, 'to': widget.otherId})
          : await ApiClient.multipart(_base, {'text': text, 'to': widget.otherId}, files: {'image': image});
      _text.clear();
      _append(ChatMessage.fromJson(Map<String, dynamic>.from(res)));
      if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final file = await pickImage(context, maxWidth: 1400);
    if (file != null) await _send(image: file);
  }

  void _openSubject() {
    if (_isTool) {
      push(context, ToolDetailScreen(toolId: widget.toolId));
      return;
    }
    final role = AuthService.instance.user!.role;
    push(context, role == 'technician' ? TechJobDetail(jobId: widget.jobId) : JobDetailClient(jobId: widget.jobId));
  }

  @override
  Widget build(BuildContext context) {
    final msgs = _messages;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          AppAvatar(name: widget.otherName, url: widget.otherAvatar, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.otherName.isEmpty ? 'Chat' : widget.otherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _otherTyping ? 'typing…' : widget.jobTitle,
                  key: ValueKey(_otherTyping),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _otherTyping ? context.palette.success : context.palette.muted,
                  ),
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: _isTool ? 'View tool' : 'View job',
            onPressed: _openSubject,
            icon: Icon(_isTool ? Icons.handyman_outlined : Icons.work_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: msgs == null
                ? (_error != null
                    ? ErrorView(message: _error.toString(), onRetry: _load)
                    : const Center(child: CircularProgressIndicator()))
                : msgs.isEmpty
                    ? EmptyState(
                        icon: Icons.waving_hand_rounded,
                        title: 'Say hello to ${widget.otherName.split(' ').first}',
                        message: _isTool
                            ? 'Ask about the tool, pickup times, delivery or the return.'
                            : 'Ask about availability, materials or anything else about the job.',
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        itemCount: msgs.length,
                        itemBuilder: (_, i) {
                          final idx = msgs.length - 1 - i;
                          final m = msgs[idx];
                          final prev = idx > 0 ? msgs[idx - 1] : null;
                          final newDay = prev == null || !_sameDay(prev.createdAt, m.createdAt);
                          final grouped = prev != null && !newDay && prev.senderId == m.senderId;
                          return Column(children: [
                            if (newDay) _DaySeparator(m.createdAt),
                            _Bubble(message: m, mine: m.senderId == _me, grouped: grouped),
                          ]);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(color: context.palette.card, border: Border(top: BorderSide(color: context.palette.border))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                      tooltip: 'Send a photo', onPressed: _sending ? null : _attach, icon: const Icon(Icons.add_photo_alternate_outlined)),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _onTyping,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        isDense: true,
                        filled: true,
                        fillColor: context.palette.fill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _sending ? null : () => _send(),
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime date;
  const _DaySeparator(this.date);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: context.palette.fill, borderRadius: BorderRadius.circular(12)),
            child: Text(Fmt.dayLabel(date), style: TextStyle(fontSize: 12, color: context.palette.muted, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool grouped;
  const _Bubble({required this.message, required this.mine, required this.grouped});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = mine ? context.colors.primary : p.card;
    final fg = mine ? Colors.white : context.colors.onSurface;
    const r = Radius.circular(18);
    const small = Radius.circular(6);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: grouped ? 2 : 8, left: mine ? 56 : 0, right: mine ? 0 : 56),
        decoration: BoxDecoration(
          color: bg,
          border: mine ? null : Border.all(color: p.border),
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: mine ? r : small,
            bottomRight: mine ? small : r,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.image.isNotEmpty)
              GestureDetector(
                onTap: () => PhotoViewer.open(context, [message.image]),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240, maxHeight: 260),
                  child: NetImage(message.image, fit: BoxFit.cover, width: 240, height: 200),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  if (message.text.isNotEmpty) Text(message.text, style: TextStyle(color: fg, fontSize: 15, height: 1.35)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(Fmt.time(message.createdAt), style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : p.subtle)),
                    if (mine) ...[
                      const SizedBox(width: 3),
                      Icon(
                        message.readAt != null ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 15,
                        color: message.readAt != null ? const Color(0xFF9AE6FF) : Colors.white70,
                      ),
                    ],
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
