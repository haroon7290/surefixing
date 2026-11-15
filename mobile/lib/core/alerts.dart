import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/json.dart';

/// Phone notifications: they appear in the notification bar with sound and
/// vibration (and as a banner on top of other apps), and open the right
/// screen when tapped.
///
/// They are raised for realtime events, so they arrive while the app is
/// open or running in the background. When the app has been fully closed
/// nothing is listening; that would need a push service (Firebase Cloud
/// Messaging).
class Alerts {
  Alerts._();
  static final Alerts instance = Alerts._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _allowed = false;
  Json? _launch;

  /// Opens what a tapped notification is about (set by the app).
  void Function(Json payload)? onOpen;

  /// Android and iOS only (the website and desktop builds keep in-app toasts).
  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True when notifications can be shown: set up and allowed by the user.
  bool get active => _ready && _allowed;

  static const _channel = AndroidNotificationChannel(
    'surefix_alerts',
    'SureFix alerts',
    description: 'New jobs, quotes, messages, payments and rentals',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_surefix'),
          // Permission is asked for after sign-in, not at first launch.
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => _tapped(r.payload),
      );
      await _android?.createNotificationChannel(_channel);
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) _launch = _decode(launch!.notificationResponse?.payload);
      _ready = true;
      await refreshAllowed();
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Asks the user once (Android 13+ and iOS show a system prompt).
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      if (Platform.isAndroid) {
        await _android?.requestNotificationsPermission();
      } else {
        _allowed = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
    } catch (_) {
      // Already decided, or not supported.
    }
    await refreshAllowed();
  }

  /// Re-checks the permission (the user may have changed it in Settings).
  Future<void> refreshAllowed() async {
    if (!_ready) return;
    try {
      if (Platform.isAndroid) _allowed = await _android?.areNotificationsEnabled() ?? false;
      if (Platform.isIOS) {
        final ios = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
        _allowed = ios?.isEnabled ?? _allowed;
      }
    } catch (_) {}
  }

  /// Shows a notification with sound. [payload] comes back to [onOpen].
  Future<void> show(String title, String body, Json payload) async {
    if (!active) return;
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
        title: title,
        body: body,
        payload: jsonEncode(payload),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFFFF5A1F),
            styleInformation: BigTextStyleInformation(body),
            ticker: title,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentList: true, presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }

  /// Whether the app was started by tapping one of its notifications.
  bool get openedFromNotification => _launch != null;

  /// Hands over the notification that started the app, once the UI is up.
  void deliverLaunch() {
    final payload = _launch;
    _launch = null;
    if (payload != null) onOpen?.call(payload);
  }

  void _tapped(String? payload) {
    final p = _decode(payload);
    if (p != null) onOpen?.call(p);
  }

  Json? _decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return asJson(jsonDecode(s));
    } catch (_) {
      return null;
    }
  }
}
