import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationPayload {
  final String deviceId;
  final String deviceName;
  final String? tripId;
  final String title;
  final String body;

  NotificationPayload({
    required this.deviceId,
    required this.deviceName,
    this.tripId,
    required this.title,
    required this.body,
  });
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final StreamController<NotificationPayload> _notificationStream =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get onNotificationTapped => _notificationStream.stream;

  Future<void> initialize() async {
    try {
      // Request notification permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        sound: true,
      );

      debugPrint('[NotificationService] Permission status: ${settings.authorizationStatus}');

      // Subscribe to nurses topic per specification
      await _fcm.subscribeToTopic('nurses');
      debugPrint('[NotificationService] Subscribed to topic "nurses"');

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Foreground message received: ${message.data}');
        final payload = _parseMessage(message);
        if (payload != null) {
          _notificationStream.add(payload);
        }
      });

      // Handle message opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Notification clicked from background: ${message.data}');
        final payload = _parseMessage(message);
        if (payload != null) {
          _notificationStream.add(payload);
        }
      });

      // Check initial message if app launched via notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        final payload = _parseMessage(initialMessage);
        if (payload != null) {
          _notificationStream.add(payload);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Initialization error (safe fallback enabled): $e');
    }
  }

  NotificationPayload? _parseMessage(RemoteMessage message) {
    final data = message.data;
    final deviceId = data['deviceId'] as String?;
    final deviceName = data['deviceName'] as String? ?? 'IV Drip Device';
    final tripId = data['tripId'] as String?;

    if (deviceId == null) return null;

    return NotificationPayload(
      deviceId: deviceId,
      deviceName: deviceName,
      tripId: tripId,
      title: message.notification?.title ?? 'URGENT: IV Drop Stoppage Alert',
      body: message.notification?.body ?? 'Flow stoppage detected on $deviceName',
    );
  }

  /// Trigger a simulated FCM alarm broadcast for testing on physical devices or web
  void triggerSimulatedAlarm({
    required String deviceId,
    required String deviceName,
    String? tripId,
  }) {
    _notificationStream.add(
      NotificationPayload(
        deviceId: deviceId,
        deviceName: deviceName,
        tripId: tripId,
        title: 'ALERT: IV Flow Stoppage',
        body: 'Infusion flow paused or stopped on $deviceName. Immediate nurse response required.',
      ),
    );
  }

  @override
  void dispose() {
    _notificationStream.close();
    super.dispose();
  }
}
