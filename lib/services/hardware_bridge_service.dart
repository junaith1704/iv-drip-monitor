import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/trip_model.dart';
import 'trip_service.dart';
import 'notification_service.dart';

class _DevicePollingState {
  final String deviceId;
  final String boardIp;
  bool isDisposed = false;
  bool isRequestInFlight = false;
  Timer? pollTimer;
  int consecutiveFailures = 0;
  bool isOnline = false;
  DateTime? offlineStartTime;
  bool offlineNotificationShown = false;

  int? lastDrops;
  DateTime? lastDropTime;
  String? lastSpeed;
  int? lastBattery;
  double? lastDpm;

  String? lastWrittenSpeed;
  int? lastWrittenBattery;
  bool? lastWrittenBoardOnline;
  DateTime? lastHeartbeatWriteTime;

  bool isFirstTripSnapshot = true;
  String? previousTripStatus;
  DateTime? flowResumedTime;
  bool alarmRaised = false;

  _DevicePollingState({required this.deviceId, required this.boardIp});

  void dispose() {
    isDisposed = true;
    pollTimer?.cancel();
    pollTimer = null;
  }
}

class HardwareBridgeService extends ChangeNotifier {
  final TripService tripService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isRunning = false;
  final Map<String, _DevicePollingState> _deviceStates = {};
  final Map<String, bool> _deviceOnlineMap = {};
  Map<String, ActiveTripModel> _activeTripsByDeviceId = {};

  StreamSubscription<QuerySnapshot>? _devicesSubscription;
  StreamSubscription<QuerySnapshot>? _tripsSubscription;

  bool get isRunning => _isRunning;
  Map<String, bool> get deviceOnlineMap => Map.unmodifiable(_deviceOnlineMap);

  String get boardIp => '';
  String get deviceId => '';
  bool get boardOnline => _deviceOnlineMap.values.any((online) => online);
  String? get tripStatus => null;
  int? get secondsSinceLastDrop => null;
  String? get lastError => null;

  HardwareBridgeService({required this.tripService});

  bool isDeviceOnline(String deviceId) => _deviceOnlineMap[deviceId] ?? false;

  Future<void> updateConfig({String? boardIp, String? deviceId}) async {}

  Future<void> start() async {
    if (kIsWeb) return;
    if (_isRunning) return;

    _isRunning = true;

    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[HardwareBridgeService] Wakelock enable error: $e');
    }

    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('[HardwareBridgeService] Notification init error: $e');
    }

    _listenToDevices();
    _listenToActiveTrips();

    notifyListeners();
  }

  Future<void> stop() async {
    if (kIsWeb) return;
    if (!_isRunning) return;

    _isRunning = false;

    await _devicesSubscription?.cancel();
    _devicesSubscription = null;

    await _tripsSubscription?.cancel();
    _tripsSubscription = null;

    for (final state in _deviceStates.values) {
      if (state.offlineNotificationShown) {
        _cancelOfflineNotification(state.deviceId);
      }
      state.dispose();
    }
    _deviceStates.clear();
    _deviceOnlineMap.clear();
    _activeTripsByDeviceId.clear();

    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[HardwareBridgeService] Wakelock disable error: $e');
    }

    notifyListeners();
  }

  void _listenToDevices() {
    _devicesSubscription?.cancel();
    _devicesSubscription = _firestore.collection('devices').snapshots().listen((snapshot) {
      _syncDevices(snapshot.docs);
    }, onError: (e) {
      debugPrint('[HardwareBridgeService] Devices stream error: $e');
    });
  }

  void _listenToActiveTrips() {
    _tripsSubscription?.cancel();
    _tripsSubscription = _firestore.collection('activeTrips').snapshots().listen((snapshot) {
      _syncTrips(snapshot.docs);
    }, onError: (e) {
      debugPrint('[HardwareBridgeService] Trips stream error: $e');
    });
  }

  void _syncDevices(List<QueryDocumentSnapshot> docs) {
    if (!_isRunning) return;

    final currentDeviceIps = <String, String>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final boardIp = data['boardIp'] as String?;
      if (boardIp != null && boardIp.trim().isNotEmpty) {
        currentDeviceIps[doc.id] = boardIp.trim();
      }
    }

    final removedIds = _deviceStates.keys
        .where((id) => !currentDeviceIps.containsKey(id) || _deviceStates[id]!.boardIp != currentDeviceIps[id])
        .toList();

    for (final id in removedIds) {
      final state = _deviceStates.remove(id);
      if (state != null) {
        if (state.offlineNotificationShown) {
          _cancelOfflineNotification(state.deviceId);
        }
        state.dispose();
      }
      _deviceOnlineMap.remove(id);
    }

    int staggerIndex = 0;
    currentDeviceIps.forEach((deviceId, boardIp) {
      if (!_deviceStates.containsKey(deviceId)) {
        final state = _DevicePollingState(deviceId: deviceId, boardIp: boardIp);
        _deviceStates[deviceId] = state;
        _deviceOnlineMap[deviceId] = false;

        final trip = _activeTripsByDeviceId[deviceId];
        if (trip != null) {
          state.isFirstTripSnapshot = false;
          if (trip.status == 'stuck') {
            state.alarmRaised = true;
          }
          state.previousTripStatus = trip.status;
        }

        final delay = Duration(milliseconds: staggerIndex * 300);
        staggerIndex++;
        state.pollTimer = Timer(delay, () => _pollDevice(state));
      }
    });

    notifyListeners();
  }

  void _syncTrips(List<QueryDocumentSnapshot> docs) {
    if (!_isRunning) return;

    final newTripsByDeviceId = <String, ActiveTripModel>{};
    for (final doc in docs) {
      final trip = ActiveTripModel.fromFirestore(doc);
      newTripsByDeviceId[trip.deviceId] = trip;
    }
    _activeTripsByDeviceId = newTripsByDeviceId;

    for (final entry in _deviceStates.entries) {
      final deviceId = entry.key;
      final state = entry.value;
      final trip = newTripsByDeviceId[deviceId];
      _onTripUpdated(state, trip);
    }
  }

  void _onTripUpdated(_DevicePollingState state, ActiveTripModel? trip) {
    if (trip == null) {
      state.previousTripStatus = null;
      state.alarmRaised = false;
      state.flowResumedTime = null;
      state.lastDropTime = null;
      state.isFirstTripSnapshot = true;
      if (state.offlineNotificationShown) {
        state.offlineNotificationShown = false;
        _cancelOfflineNotification(state.deviceId);
      }
      return;
    }

    if (state.isFirstTripSnapshot) {
      state.isFirstTripSnapshot = false;
      if (trip.status == 'stuck') {
        state.alarmRaised = true;
      }
    } else if (state.previousTripStatus == 'stuck' && trip.status == 'running') {
      state.alarmRaised = false;
      state.flowResumedTime = DateTime.now();
    }
    state.previousTripStatus = trip.status;
  }

  Future<void> _pollDevice(_DevicePollingState state) async {
    if (!_isRunning || state.isDisposed || state.isRequestInFlight) return;
    state.isRequestInFlight = true;

    try {
      final url = Uri.parse('http://${state.boardIp}/api');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _handleSuccess(state, data);
      } else {
        await _handleFailure(state);
      }
    } catch (e) {
      debugPrint('[HardwareBridgeService] Poll error for ${state.deviceId}: $e');
      await _handleFailure(state);
    } finally {
      state.isRequestInFlight = false;
      if (_isRunning && !state.isDisposed) {
        state.pollTimer?.cancel();
        state.pollTimer = Timer(const Duration(seconds: 3), () => _pollDevice(state));
      }
    }
  }

  Future<void> _handleSuccess(_DevicePollingState state, Map<String, dynamic> data) async {
    state.consecutiveFailures = 0;
    if (!state.isOnline) {
      state.isOnline = true;
      _deviceOnlineMap[state.deviceId] = true;
      notifyListeners();
    }
    state.offlineStartTime = null;
    if (state.offlineNotificationShown) {
      state.offlineNotificationShown = false;
      _cancelOfflineNotification(state.deviceId);
    }

    final drops = data['drops'] is num ? (data['drops'] as num).toInt() : null;
    final dpm = data['dpm'] is num ? (data['dpm'] as num).toDouble() : null;
    final battery = data['battery'] is num ? (data['battery'] as num).toInt() : null;
    final speed = data['speed'] as String?;

    if (drops != null) {
      if (state.lastDrops != null && drops < state.lastDrops!) {
        state.lastDrops = drops;
        state.lastDropTime = DateTime.now();
      } else if (state.lastDrops == null || drops > state.lastDrops!) {
        state.lastDrops = drops;
        state.lastDropTime = DateTime.now();
      }
    }

    state.lastSpeed = speed;
    state.lastBattery = battery;
    state.lastDpm = dpm;

    await _maybeWriteTelemetry(
      state: state,
      speed: speed,
      battery: battery,
      dpm: dpm,
      boardOnline: true,
    );

    _checkStall(state);
  }

  Future<void> _handleFailure(_DevicePollingState state) async {
    state.consecutiveFailures++;

    if (state.consecutiveFailures >= 5) {
      if (state.isOnline) {
        state.isOnline = false;
        state.offlineStartTime = DateTime.now();
        _deviceOnlineMap[state.deviceId] = false;
        notifyListeners();
      } else {
        state.offlineStartTime ??= DateTime.now();
        _deviceOnlineMap[state.deviceId] = false;
      }

      await _maybeWriteTelemetry(
        state: state,
        speed: state.lastSpeed,
        battery: state.lastBattery,
        dpm: state.lastDpm,
        boardOnline: false,
      );

      final trip = _activeTripsByDeviceId[state.deviceId];
      if (trip != null && trip.status == 'running' && state.offlineStartTime != null) {
        if (DateTime.now().difference(state.offlineStartTime!) >= const Duration(seconds: 20)) {
          if (!state.offlineNotificationShown) {
            state.offlineNotificationShown = true;
            await _showOfflineNotification(state.deviceId, trip.deviceName);
            try {
              await _firestore.collection('devices').doc(state.deviceId).set({
                'boardOnline': false,
                'lastUpdated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (e) {
              debugPrint('[HardwareBridgeService] Write offline error for ${state.deviceId}: $e');
            }
          }
        }
      }
    }
  }

  Future<void> _maybeWriteTelemetry({
    required _DevicePollingState state,
    required String? speed,
    required int? battery,
    required double? dpm,
    required bool boardOnline,
  }) async {
    final now = DateTime.now();
    final bool stateChanged = speed != state.lastWrittenSpeed ||
        battery != state.lastWrittenBattery ||
        boardOnline != state.lastWrittenBoardOnline;

    final bool heartbeatDue = state.lastHeartbeatWriteTime == null ||
        now.difference(state.lastHeartbeatWriteTime!) >= const Duration(seconds: 60);

    if (!stateChanged && !heartbeatDue) {
      return;
    }

    state.lastWrittenSpeed = speed;
    state.lastWrittenBattery = battery;
    state.lastWrittenBoardOnline = boardOnline;
    state.lastHeartbeatWriteTime = now;

    try {
      await _firestore.collection('devices').doc(state.deviceId).set({
        'speed': speed,
        'battery': battery,
        'dpm': dpm,
        'boardOnline': boardOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[HardwareBridgeService] Write telemetry error for ${state.deviceId}: $e');
    }
  }

  void _checkStall(_DevicePollingState state) {
    final trip = _activeTripsByDeviceId[state.deviceId];
    if (trip == null || trip.status != 'running') {
      return;
    }

    if (state.alarmRaised) {
      return;
    }

    final now = DateTime.now();
    DateTime referenceTime = state.lastDropTime ?? trip.startTime;
    final graceTime = trip.startTime.add(const Duration(seconds: 60));
    if (graceTime.isAfter(referenceTime)) {
      referenceTime = graceTime;
    }
    if (state.flowResumedTime != null && state.flowResumedTime!.isAfter(referenceTime)) {
      referenceTime = state.flowResumedTime!;
    }

    if (now.difference(referenceTime) >= const Duration(seconds: 20)) {
      state.alarmRaised = true;
      tripService.simulateDropStop(deviceId: state.deviceId);
      NotificationService().showStuckNotification(
        deviceId: state.deviceId,
        deviceName: trip.deviceName,
        tripId: trip.tripId,
      );
    }
  }

  Future<void> _showOfflineNotification(String deviceId, String deviceName) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'board_offline_channel',
      'Hardware Status',
      channelDescription: 'Notifications for hardware connectivity issues',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);
    final int notifId = (deviceId.hashCode & 0x7FFFFFFF) ^ 0x12345678;
    await _notificationsPlugin.show(
      notifId,
      'Hardware Notice',
      'Board not responding, check the drip manually ($deviceName)',
      details,
    );
  }

  Future<void> _cancelOfflineNotification(String deviceId) async {
    if (kIsWeb) return;
    final int notifId = (deviceId.hashCode & 0x7FFFFFFF) ^ 0x12345678;
    await _notificationsPlugin.cancel(notifId);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
