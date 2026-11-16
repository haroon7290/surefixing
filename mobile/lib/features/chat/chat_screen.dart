import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../kit.dart';
import '../../routes.dart';

/// A conversation as its own page (phones, or opened from a job or tool).
class ChatScreen extends StatelessWidget {
  final ChatTarget target;
  const ChatScreen({super.key, required this.target});

  // Which conversation is on screen, so the app does not toast messages
  // the user is already reading.
  static String? _openThread;
  static String? _openOther;
  static bool isOpen(String thread, String otherId) => _openThread == thread && _openOther == otherId;

  @override
  Widget build(BuildContext context) => AppPage(
        title: target.otherName.isEmpty ? 'Chat' : (target.isSupport && target.asTeam ? '${target.otherName} · Support' : target.otherName),
        maxWidth: 820,
        body: ChatView(target: target),
      );
}

/// Messages + composer for one thread. Live: new messages, read receipts
/// and the typing indicator arrive over the socket.
class ChatView extends StatefulWidget {
  final ChatTarget target;
  final bool showHeader;
  const ChatView({super.key, required this.target, this.showHeader = false});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  List<Message> _messages = [];
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  bool _otherTyping = false;
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _typingOff;
  Timer? _typingSent;

  ChatTarget get _t => widget.target;
  String get _me => Session.instance.user?.id ?? '';

  /// Whether a message is on "my" side: mine, or (admins in a support
  /// chat) written by anyone on the SureFix team.
  bool _mine(Message m) => m.senderId == _me || (_t.isSupport && _t.asTeam && m.fromSupport);

  /// Whether a message came from the other side of this conversation.
  bool _fromOther(Message m) => _t.isSupport ? m.fromSupport != _t.asTeam : m.senderId == _t.otherId;

  @override
  void initState() {
    super.initState();
    ChatScreen._openThread = _t.thread;
    ChatScreen._openOther = _t.otherId;
    _load();
    _sub = Realtime.instance.on(const {'message:new', 'message:read', 'typing'}).listen(_onEvent);
  }

  @override
  void dispose() {
    if (ChatScreen.isOpen(_t.thread, _t.otherId)) {
      ChatScreen._openThread = null;
      ChatScreen._openOther = null;
    }
    _sub?.cancel();
    _typingOff?.cancel();
    _typingSent?.cancel();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await Api.list(_t.path, query: {'with': _t.otherId});
      if (!mounted) return;
      setState(() {
        _messages = rows.map(Message.fromJson).toList();
        _loading = false;
        _error = null;
      });
      Badges.instance.refresh();
      _toBottom(jump: true);
    } catch (e) {
      if (mounted) setState(() => (_error = e, _loading = false));
    }
  }

  void _onEvent(RealtimeEvent e) {
    final thread = str(e.data['thread'], str(e.data['jobId']));
    if (thread != _t.thread) return;
    switch (e.name) {
      case 'message:new':
        final m = Message.fromJson(e.data);
        // Support threads have one conversation per thread key.
        final involves = _t.isSupport || (m.senderId == _t.otherId && m.recipientId == _me) || (m.senderId == _me && m.recipientId == _t.otherId);
        if (!involves || _messages.any((x) => x.id == m.id)) return;
        setState(() {
          _messages = [..._messages, m];
          if (_fromOther(m)) _otherTyping = false;
        });
        _toBottom();
        if (_fromOther(m)) {
          Api.post('${_t.path}/read', {'with': _t.otherId}).then((_) => Badges.instance.refresh()).catchError((_) {});
        }
      case 'message:read':
        if (str(e.data['by']) != _t.otherId) return;
        setState(() => _messages = [for (final m in _messages) _mine(m) && !m.read ? m.markedRead() : m]);
      case 'typing':
        if (str(e.data['from']) != _t.otherId) return;
        setState(() => _otherTyping = e.data['typing'] != false);
        _typingOff?.cancel();
        _typingOff = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _otherTyping = false);
        });
    }
  }

  void _toBottom({bool jump = false}) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final end = _scroll.position.maxScrollExtent;
        jump ? _scroll.jumpTo(end) : _scroll.animateTo(end, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      });

  void _onTyping(String _) {
    if (_t.isSupport || (_typingSent?.isActive ?? false)) return;
    Realtime.instance.emit('typing', {'to': _t.otherId, 'jobId': _t.thread, 'typing': true});
    _typingSent = Timer(const Duration(seconds: 2), () {});
  }

  Future<void> _send({XFile? image}) async {
    final text = _input.text.trim();
    if (_sending || (text.isEmpty && image == null)) return;
    setState(() => _sending = true);
    if (image == null) _input.clear();
    // The team states the topic once per topic ("Re: Job …"), not on every message.
    final lastAbout = _messages.lastWhere((m) => m.about.isNotEmpty, orElse: () => const Message(id: '')).about;
    final about = _t.isSupport && _t.asTeam && _t.about.isNotEmpty && _t.about != lastAbout ? _t.about : '';
    try {
      final res = image == null
          ? await Api.post(_t.path, {'text': text, 'to': _t.otherId, if (about.isNotEmpty) 'about': about})
          : await Api.upload(_t.path, fields: {
              'text': '',
              'to': _t.otherId,
              if (about.isNotEmpty) 'about': about,
            }, files: {
              'image': [image]
            });
      final m = Message.fromJson(asJson(res));
      if (mounted && !_messages.any((x) => x.id == m.id)) {
        setState(() => _messages = [..._messages, m]);
        _toBottom();
      }
    } catch (e) {
      toastError(e);
      if (image == null && mounted && _input.text.isEmpty) _input.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final subject = _t.subject;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = ErrorState(
          error: _error!,
          onRetry: () {
            setState(() => _loading = true);
            _load();
          });
    } else if (_messages.isEmpty) {
      body = _t.isSupport
          ? EmptyState(
              icon: AppIcons.help,
              title: _t.asTeam ? 'Message ${_t.otherName.split(' ').first} as SureFix' : 'How can we help?',
              message: _t.asTeam
                  ? 'They will see your messages from "SureFix Support", not from you.${_t.about.isEmpty ? '' : ' Your first message is marked "Re: ${_t.about}".'}'
                  : 'Ask about payments, verification, a job or anything else. The SureFix team replies here.',
            )
          : EmptyState(
              icon: AppIcons.chat,
              title: 'Say hello to ${_t.otherName.split(' ').first}',
              message: _t.isTool ? 'Ask about the tool, or arrange pickup and return.' : 'Ask questions, share photos and agree the details before work starts.',
            );
    } else {
      final lastMine = _messages.lastIndexWhere(_mine);
      body = ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: _messages.length + (_otherTyping ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _messages.length) return const _TypingBubble();
          final m = _messages[i];
          final prev = i == 0 ? null : _messages[i - 1];
          final newDay = prev == null || (m.createdAt != null && prev.createdAt != null && dayLabel(m.createdAt!) != dayLabel(prev.createdAt!));
          return Column(mainAxisSize: MainAxisSize.min, children: [
            if (newDay && m.createdAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(999)),
                  child: Text(dayLabel(m.createdAt!), style: context.text.bodySmall!.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ),
            _Bubble(
              m,
              mine: _mine(m),
              joined: !newDay && prev.senderId == m.senderId && m.about.isEmpty,
              showStatus: i == lastMine,
              // Admins see which teammate wrote each support message.
              by: _t.asTeam && m.fromSupport && m.senderId != _me ? m.senderName : '',
            ),
          ]);
        },
      );
    }

    return Column(children: [
      if (widget.showHeader)
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: _t.isSupport && !_t.asTeam
              ? Row(children: [
                  const BrandMark(size: 42),
                  Gap.w12,
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(ChatTarget.supportName, style: context.text.titleMedium),
                      Text('The SureFix team', style: context.text.bodySmall),
                    ]),
                  ),
                ])
              : PersonRow(name: _t.otherName, image: _t.otherAvatar, subtitle: _t.isSupport ? 'Support conversation · they see you as SureFix Support' : subject, size: 42),
        )
      else if (_t.isSupport)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line), bottom: BorderSide(color: c.line))),
          child: Row(children: [
            Icon(AppIcons.shieldFill, size: 15, color: c.brand),
            Gap.w8,
            Expanded(
              child: Text(
                _t.asTeam ? 'You are writing as SureFix Support${_t.about.isEmpty ? '' : ' · Re: ${_t.about}'}' : 'Official SureFix team',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium!.copyWith(color: c.ink),
              ),
            ),
          ]),
        )
      else if (subject.isNotEmpty)
        Semantics(
          button: true,
          child: InkWell(
            onTap: () => _t.isTool ? openTool(context, _t.toolId) : openJob(context, _t.jobId),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line), bottom: BorderSide(color: c.line))),
              child: Row(children: [
                Icon(_t.isTool ? AppIcons.tools : AppIcons.jobs, size: 15, color: c.body),
                Gap.w8,
                Expanded(child: Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium!.copyWith(color: c.ink))),
                Icon(AppIcons.chevronRight, size: 12, color: c.muted),
              ]),
            ),
          ),
        ),
      Expanded(child: body),
      Container(
        decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
        padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + (widget.showHeader ? 0 : MediaQuery.paddingOf(context).bottom)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          IconButton(
            tooltip: 'Send a photo',
            onPressed: _sending
                ? null
                : () async {
                    final file = await pickPhoto(context);
                    if (file != null) _send(image: file);
                  },
            icon: Icon(AppIcons.camera, color: c.body),
          ),
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onChanged: _onTyping,
              onSubmitted: (_) => _send(),
              style: context.text.bodyLarge!.copyWith(color: c.ink, fontSize: 15.5),
              decoration: InputDecoration(
                hintText: 'Write a message',
                counterText: '',
                fillColor: c.sunken,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c.ink, width: 1.2)),
              ),
            ),
          ),
          Gap.w8,
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: RoundBtn(AppIcons.send, tooltip: 'Send', size: 44, background: c.brand, color: c.onBrand, bordered: false, onPressed: _sending ? null : _send),
          ),
        ]),
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool mine;
  final String by;
  final bool joined; // follows another message from the same person
  final bool showStatus;
  const _Bubble(this.message, {required this.mine, required this.joined, required this.showStatus, this.by = ''});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = message;
    final fg = mine ? c.canvas : c.ink;
    const big = Radius.circular(18);
    const small = Radius.circular(6);
    return Padding(
      padding: EdgeInsets.only(top: joined ? 3 : 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: (MediaQuery.sizeOf(context).width * 0.76).clamp(220, 520)),
          child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // Support messages from the team can say what they are about.
            if (m.about.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.tag, size: 12, color: c.muted),
                  Gap.w4,
                  Flexible(child: Text('Re: ${m.about}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall!.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700))),
                ]),
              ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: mine ? c.ink : c.surface,
                border: mine ? null : Border.all(color: c.line),
                borderRadius: BorderRadius.only(topLeft: big, topRight: big, bottomLeft: mine ? big : small, bottomRight: mine ? small : big),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (m.image.isNotEmpty)
                  Semantics(
                    button: true,
                    label: 'Photo',
                    child: GestureDetector(onTap: () => openGallery(context, [m.image]), child: NetImage(m.image, width: 240, height: 180)),
                  ),
                if (m.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
                    child: Text(m.text, style: TextStyle(fontFamily: kBodyFont, fontSize: 15, height: 1.4, fontWeight: FontWeight.w500, color: fg)),
                  ),
              ]),
            ),
            if (showStatus || !joined || by.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                child: Text(
                  '${by.isEmpty ? '' : '$by  ·  '}${clock(m.createdAt)}${mine && showStatus ? (m.read ? '  ·  Read' : '  ·  Sent') : ''}',
                  style: context.text.bodySmall!.copyWith(fontSize: 11),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(18)),
          child: Text('typing…', style: context.text.bodySmall!.copyWith(fontStyle: FontStyle.italic)),
        ),
      ),
    );
  }
}
