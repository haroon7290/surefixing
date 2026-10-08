import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/realtime_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List _items = [];
  bool _loading = true;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = RealtimeService.instance.events.listen((e) {
      if (e.name != 'notification') return;
      if (!mounted) return;
      // Prepend the live notification (matches backend's createdAt-desc order).
      setState(() => _items = [Map<String, dynamic>.from(e.data), ..._items]);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/users/me/notifications');
      setState(() => _items = res as List);
    } catch (_) {
      // Silent: notifications UI degrades gracefully if the list fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'bid':
        return Icons.gavel;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'job_status':
        return Icons.build;
      case 'kyc':
        return Icons.verified_user;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No notifications yet'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = _items[i];
                    return ListTile(
                      leading: Icon(_icon(n['type'] ?? '')),
                      title: Text(n['title'] ?? ''),
                      subtitle: Text(n['body'] ?? ''),
                      trailing: n['readAt'] == null
                          ? const Icon(Icons.circle, size: 10, color: Colors.blue)
                          : null,
                      onTap: () async {
                        await ApiClient.post('/api/users/me/notifications/${n['_id']}/read');
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}
