import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final StreamController<NotificationPayload> _notificationStream =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get onNotificationTapped => _notificationStream.stream;

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[NotificationService] Skipping FCM setup on web');
      return;
    }
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        sound: true,
      );

      debugPrint('[NotificationService] Permission status: ${settings.authorizationStatus}');

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final raw = response.payload;
          if (raw != null && raw.contains('|')) {
            final parts = raw.split('|');
            _notificationStream.add(
              NotificationPayload(
                deviceId: parts[0],
                deviceName: parts[1],
                tripId: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
                title: 'URGENT: IV Flow Stoppage',
                body: 'Device ${parts[1]} (${parts[0]}) is stuck.',
              ),
            );
          }
        },
      );

      const legacyChannel = AndroidNotificationChannel(
        'iv_stall_alarm_channel',
        'IV Stall Alarms',
        description: 'High priority alarms for IV flow stall',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final stuckChannel = AndroidNotificationChannel(
        'stuck_alarm',
        'Stuck Alarms',
        description: 'Critical alarms for stuck IV drip devices',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(legacyChannel);
      await androidPlugin?.createNotificationChannel(stuckChannel);

      await _fcm.subscribeToTopic('nurses');
      debugPrint('[NotificationService] Subscribed to topic "nurses"');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Foreground message received: ${message.data}');
        final payload = _parseMessage(message);
        if (payload != null) {
          _notificationStream.add(payload);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Notification clicked from background: ${message.data}');
        final payload = _parseMessage(message);
        if (payload != null) {
          _notificationStream.add(payload);
        }
      });

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        final payload = _parseMessage(initialMessage);
        if (payload != null) {
          _notificationStream.add(payload);
        }
      }

      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final raw = launchDetails.notificationResponse?.payload;
        if (raw != null && raw.contains('|')) {
          final parts = raw.split('|');
          _notificationStream.add(
            NotificationPayload(
              deviceId: parts[0],
              deviceName: parts[1],
              tripId: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
              title: 'URGENT: IV Flow Stoppage',
              body: 'Device ${parts[1]} (${parts[0]}) is stuck.',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  int getNotificationId(String deviceId) => deviceId.hashCode & 0x7FFFFFFF;

  Future<void> showStuckNotification({
    required String deviceId,
    required String deviceName,
    String? tripId,
  }) async {
    if (kIsWeb) return;
    final int id = getNotificationId(deviceId);
    final androidDetails = AndroidNotificationDetails(
      'stuck_alarm',
      'Stuck Alarms',
      channelDescription: 'Critical alarms for stuck IV drip devices',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      category: AndroidNotificationCategory.alarm,
      additionalFlags: Int32List.fromList([4]),
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
    );
    final details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      id,
      'URGENT: IV Flow Stoppage',
      'Device $deviceName ($deviceId) is stuck.',
      details,
      payload: '$deviceId|$deviceName|${tripId ?? ''}',
    );
  }

  Future<void> cancelStuckNotification(String deviceId) async {
    if (kIsWeb) return;
    final int id = getNotificationId(deviceId);
    await _localNotifications.cancel(id);
  }

  Future<void> showStallAlarm(String deviceName) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'iv_stall_alarm_channel',
      'IV Stall Alarms',
      channelDescription: 'High priority alarms for IV flow stall',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'URGENT: IV Drop Stoppage',
      'Flow stoppage detected on $deviceName',
      details,
    );
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
