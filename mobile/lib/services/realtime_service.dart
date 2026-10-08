import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_config.dart';

class RealtimeEvent {
  final String name;
  final Map<String, dynamic> data;
  RealtimeEvent(this.name, this.data);

  String get jobId => (data['jobId'] ?? data['job'] ?? '').toString();
}

// Server events forwarded onto [RealtimeService.events]. Adding a new
// server-side event? List its name here.
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
  'kyc:new',
  'report:new',
];

/// Socket.IO connection to the backend. Screens subscribe to [events] to
/// refresh live; [connected] drives the "offline" banner.
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  final _controller = StreamController<RealtimeEvent>.broadcast();
  final ValueNotifier<bool> connected = ValueNotifier(false);

  Stream<RealtimeEvent> get events => _controller.stream;

  /// Events filtered by name, e.g. `on({'job:new', 'job:bid'})`.
  Stream<RealtimeEvent> on(Set<String> names) => events.where((e) => names.contains(e.name));

  void connect(String token) {
    if (_socket != null) return;
    _socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder().setTransports(['websocket', 'polling']).setAuth({'token': token}).enableReconnection().build(),
    );
    _socket!
      ..onConnect((_) => connected.value = true)
      ..onDisconnect((_) => connected.value = false)
      ..onConnectError((_) => connected.value = false);
    for (final name in _subscribed) {
      _socket!.on(name, (data) {
        final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _controller.add(RealtimeEvent(name, map));
      });
    }
  }

  void emit(String event, Map<String, dynamic> data) {
    if (_socket?.connected ?? false) _socket!.emit(event, data);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }
}
