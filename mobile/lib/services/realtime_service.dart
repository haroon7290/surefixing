import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_config.dart';

class RealtimeEvent {
  final String name;
  final Map<String, dynamic> data;
  RealtimeEvent(this.name, this.data);
}

// Subscribed-to events. Adding a new server-side event? List its name here so
// the socket forwards it onto the [events] stream.
const _subscribed = [
  'notification',
  'job:new',
  'job:bid',
  'job:hired',
  'job:status',
  'job:rated',
  'tool:rented',
  'tool:purchased',
  'message:new',
];

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;
  bool get connected => _socket?.connected ?? false;

  void connect(String token) {
    if (_socket != null) return;
    _socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    for (final name in _subscribed) {
      _socket!.on(name, (data) {
        final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _controller.add(RealtimeEvent(name, map));
      });
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
