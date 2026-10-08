import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_service.dart';

class MessagesScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String counterpartyName;
  const MessagesScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.counterpartyName,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  Timer? _poll;
  StreamSubscription<RealtimeEvent>? _sub;
  bool _sending = false;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Polling kept as a safety net for missed socket events / cold-start
    // races; live append via socket is the primary path.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    _sub = RealtimeService.instance.events.listen((e) {
      if (e.name != 'message:new') return;
      if ((e.data['job'] ?? '').toString() != widget.jobId) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(e.data));
      if (_messages.any((m) => m.id == msg.id)) return; // dedupe
      if (!mounted) return;
      setState(() => _messages = [..._messages, msg]);
      _scrollIfAtBottom(force: msg.senderId == AuthService.instance.user!.id);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _scrollIfAtBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      // Auto-scroll on first load, when the user is the sender, or when
      // they're already within 80px of the bottom. Otherwise leave them alone.
      final atBottom = pos.maxScrollExtent - pos.pixels < 80;
      if (force || _firstLoad || atBottom) {
        _scroll.jumpTo(pos.maxScrollExtent);
        _firstLoad = false;
      }
    });
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.get('/api/messages/${widget.jobId}') as List;
      final msgs = res.map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e))).toList();
      if (!mounted) return;
      setState(() => _messages = msgs);
      _scrollIfAtBottom();
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiClient.post('/api/messages/${widget.jobId}', {'text': text});
      _text.clear();
      // The message will arrive over the socket and be appended; no need
      // to _load() and no optimistic insert (avoids dedup ambiguity).
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meId = AuthService.instance.user!.id;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.counterpartyName, style: const TextStyle(fontSize: 16)),
            Text(widget.jobTitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final mine = m.senderId == meId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: mine ? Colors.indigo : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(color: mine ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
