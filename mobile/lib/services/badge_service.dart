import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'realtime_service.dart';

/// Unread counters for the navigation badges (chat + notifications). Kept
/// fresh by realtime events, and re-synced from the server on demand.
class BadgeService {
  BadgeService._();
  static final BadgeService instance = BadgeService._();

  final ValueNotifier<int> unreadMessages = ValueNotifier(0);
  final ValueNotifier<int> unreadNotifications = ValueNotifier(0);
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _debounce;

  void start() {
    _sub ??= RealtimeService.instance.events.listen((e) {
      if (e.name == 'notification') {
        unreadNotifications.value += 1;
      } else if (e.name == 'message:new') {
        final me = AuthService.instance.user?.id;
        if (e.data['sender']?.toString() != me) unreadMessages.value += 1;
      }
    });
    refresh();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    unreadMessages.value = 0;
    unreadNotifications.value = 0;
  }

  /// Re-reads both counts from the server (debounced).
  void refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!AuthService.instance.loggedIn) return;
      try {
        final results = await Future.wait([
          ApiClient.getMap('/api/messages/unread-count'),
          ApiClient.getMap('/api/users/me/notifications/unread-count'),
        ]);
        unreadMessages.value = (results[0]['count'] as num?)?.toInt() ?? 0;
        unreadNotifications.value = (results[1]['count'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    });
  }
}
