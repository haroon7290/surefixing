import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/json.dart';
import 'api.dart';
import 'session.dart';

class RealtimeEvent {
  final String name;
  final Json data;
  const RealtimeEvent(this.name, this.data);

  String get jobId => str(data['jobId'] ?? data['job']);
}

/// Server events forwarded onto [Realtime.events]. Adding a server-side
/// event? List its name here.
const _subscribed = [
  'notification',
  'job:new',
  'job:request',
  'job:bid',
  'job:hired',
  'job:status',
  'job:rated',
  'rental:new',
  'rental:update',
  'message:new',
  'message:read',
  'typing',
  'wallet:update',
  'kyc:new',
  'report:new',
];

/// Event groups screens refresh on.
abstract final class Live {
  static const jobs = {'job:new', 'job:request', 'job:bid', 'job:hired', 'job:status', 'job:rated'};
  static const rentals = {'rental:new', 'rental:update'};
  static const messages = {'message:new', 'message:read'};
  static const wallet = {'wallet:update'};
  static const notifications = {'notification'};
  static const admin = {'kyc:new', 'report:new'};
}

/// Socket.IO connection to the backend. Screens subscribe to [events] to
/// refresh live; [connected] drives the "reconnecting" banner.
class Realtime {
  Realtime._();
  static final Realtime instance = Realtime._();

  io.Socket? _socket;
  final _controller = StreamController<RealtimeEvent>.broadcast();
  final ValueNotifier<bool> connected = ValueNotifier(false);

  Stream<RealtimeEvent> get events => _controller.stream;

  Stream<RealtimeEvent> on(Set<String> names) => events.where((e) => names.contains(e.name));

  void connect(String token) {
    if (_socket != null) return;
    final socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder().setTransports(['websocket', 'polling']).setAuth({'token': token}).enableReconnection().build(),
    );
    socket
      ..onConnect((_) => connected.value = true)
      ..onDisconnect((_) => connected.value = false)
      ..onConnectError((_) => connected.value = false);
    for (final name in _subscribed) {
      socket.on(name, (data) => _controller.add(RealtimeEvent(name, asJson(data))));
    }
    _socket = socket;
  }

  void emit(String event, Json data) {
    if (_socket?.connected ?? false) _socket!.emit(event, data);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }

  /// Test hook: deliver an event as if the server sent it.
  @visibleForTesting
  void debugAdd(String name, [Json data = const {}]) => _controller.add(RealtimeEvent(name, data));
}

/// Unread counters for the navigation badges, kept fresh by realtime events
/// and re-read from the server on demand.
class Badges {
  Badges._();
  static final Badges instance = Badges._();

  final ValueNotifier<int> messages = ValueNotifier(0);
  final ValueNotifier<int> notifications = ValueNotifier(0);
  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _debounce;

  void start() {
    _sub ??= Realtime.instance.events.listen((e) {
      switch (e.name) {
        case 'notification':
          notifications.value += 1;
        case 'message:new':
          if (str(e.data['sender']) != Session.instance.user?.id) messages.value += 1;
        case 'wallet:update':
          if (e.data['balance'] is num) Session.instance.setBalance((e.data['balance'] as num).toDouble());
      }
    });
    refresh();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _debounce?.cancel();
    messages.value = 0;
    notifications.value = 0;
  }

  /// Re-reads both counts from the server (debounced).
  void refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!Session.instance.loggedIn) return;
      try {
        final results = await Future.wait([Api.map('/api/messages/unread-count'), Api.map('/api/users/me/notifications/unread-count')]);
        messages.value = integer(results[0]['count']);
        notifications.value = integer(results[1]['count']);
      } catch (_) {}
    });
  }
}
