import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';
import '../models/trip_model.dart';
import '../widgets/global_alarm_dialog.dart';
import '../screens/nurse/alarm_screen.dart';
import 'device_service.dart';
import 'trip_service.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';

class AlarmSoundManager {
  static Timer? _hapticTimer;
  static Timer? _soundTimer;
  static bool _isPlaying = false;

  static void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    });
    _soundTimer?.cancel();
    _soundTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    });
  }

  static void stop() {
    _isPlaying = false;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    _soundTimer?.cancel();
    _soundTimer = null;
  }
}

class GlobalAlarmPayload {
  final DeviceModel device;
  final ActiveTripModel? trip;
  final int totalStuckCount;

  GlobalAlarmPayload({
    required this.device,
    required this.trip,
    required this.totalStuckCount,
  });
}

class GlobalAlarmService {
  static final GlobalAlarmService instance = GlobalAlarmService._internal();

  GlobalAlarmService._internal();

  StreamSubscription? _devicesSubscription;
  Timer? _tickerTimer;
  GlobalKey<NavigatorState>? _navigatorKey;
  TripService? _tripService;

  bool _isAuthenticated = false;
  bool _isDialogOpen = false;

  bool Function()? _isBridgeRunning;
  List<DeviceModel> _stuckDevices = [];
  final Set<String> _notifiedStuckDeviceIds = <String>{};
  final Map<String, DateTime> _silencedUntil = {};
  final Map<String, DateTime> _lastSeenValues = {};
  final Map<String, DateTime> _lastSeenLocalTimes = {};
  final Set<String> _gatewayLostEpisodeActive = {};
  final Map<String, DeviceModel> _gatewayLostDevices = {};
  final Map<String, DeviceModel> _activeTripDevices = {};
  final ValueNotifier<GlobalAlarmPayload?> currentPayload = ValueNotifier<GlobalAlarmPayload?>(null);

  bool _isNurse() {
    final context = _navigatorKey?.currentContext;
    if (context == null) return false;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAdmin || authService.currentUser?.isAdmin == true) {
        return false;
      }
      return authService.currentUser?.role == 'nurse';
    } catch (_) {}
    return false;
  }

  bool _isLoginScreen() {
    final context = _navigatorKey?.currentContext;
    if (context == null) return false;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated || authService.currentUser == null) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  void startListening({
    required DeviceService deviceService,
    required TripService tripService,
    required GlobalKey<NavigatorState> navigatorKey,
    bool Function()? isBridgeRunning,
  }) {
    _navigatorKey = navigatorKey;
    _isBridgeRunning = isBridgeRunning;
    if (_isLoginScreen()) {
      return;
    }
    if (_isAuthenticated) return;
    _isAuthenticated = true;
    _tripService = tripService;

    _lastSeenValues.clear();
    _lastSeenLocalTimes.clear();
    _gatewayLostEpisodeActive.clear();
    _gatewayLostDevices.clear();
    _activeTripDevices.clear();

    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());

    _devicesSubscription?.cancel();
    if (FirebaseService.isMockFallback) {
      _devicesSubscription = deviceService.streamDevices().listen((devices) {
        _onDevicesUpdated(devices);
      });
    } else {
      _devicesSubscription = FirebaseFirestore.instance
          .collection('devices')
          .snapshots()
          .listen((snapshot) {
        final devices = snapshot.docs.map((d) => DeviceModel.fromFirestore(d)).toList();
        _onDevicesUpdated(devices);
      }, onError: (e) {
        debugPrint('[GlobalAlarmService] Error streaming devices: $e');
      });
    }
  }

  void stopListening() {
    _isAuthenticated = false;
    _devicesSubscription?.cancel();
    _devicesSubscription = null;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    AlarmSoundManager.stop();
    dismissDialog();
    _stuckDevices.clear();
    _silencedUntil.clear();
    _lastSeenValues.clear();
    _lastSeenLocalTimes.clear();
    _gatewayLostEpisodeActive.clear();
    _gatewayLostDevices.clear();
    _activeTripDevices.clear();
    currentPayload.value = null;
    for (final id in _notifiedStuckDeviceIds) {
      NotificationService().cancelStuckNotification(id);
    }
    _notifiedStuckDeviceIds.clear();
  }

  void dismissDialog() {
    AlarmSoundManager.stop();
    if (_isDialogOpen) {
      _isDialogOpen = false;
      currentPayload.value = null;
      if (_navigatorKey?.currentState?.canPop() == true) {
        _navigatorKey?.currentState?.pop();
      }
    }
  }

  void _onTick() {
    if (!_isAuthenticated) return;
    final now = DateTime.now();
    bool expiredAny = false;
    _silencedUntil.removeWhere((id, expireTime) {
      if (now.isAfter(expireTime)) {
        expiredAny = true;
        return true;
      }
      return false;
    });

    bool gatewayLostChanged = false;
    final bridgeRunning = _isBridgeRunning?.call() ?? false;
    if (!bridgeRunning) {
      for (final entry in _activeTripDevices.entries) {
        final deviceId = entry.key;
        final device = entry.value;
        if (device.status == 'stuck') continue;

        final localTime = _lastSeenLocalTimes[deviceId];
        if (localTime != null) {
          if (now.difference(localTime).inSeconds >= 45) {
            if (!_gatewayLostEpisodeActive.contains(deviceId)) {
              _gatewayLostEpisodeActive.add(deviceId);
              _gatewayLostDevices[deviceId] = device.copyWith(
                status: 'stuck',
                alarmReason: 'gateway_lost',
              );
              gatewayLostChanged = true;
              if (!_notifiedStuckDeviceIds.contains(deviceId)) {
                _notifiedStuckDeviceIds.add(deviceId);
                NotificationService().showStuckNotification(
                  deviceId: deviceId,
                  deviceName: device.currentName,
                  tripId: device.activeTripId,
                );
              }
            }
          }
        }
      }
    }

    if (expiredAny || gatewayLostChanged) {
      _evaluateState();
    }
  }

  void _onDevicesUpdated(List<DeviceModel> devices) {
    if (!_isAuthenticated) return;
    final now = DateTime.now();

    final stuck = devices.where((d) => d.status == 'stuck').toList();
    _stuckDevices = stuck;
    final currentStuckIds = stuck.map((d) => d.deviceId).toSet();
    _silencedUntil.removeWhere((id, _) => !currentStuckIds.contains(id) && !_gatewayLostDevices.containsKey(id));

    for (final device in stuck) {
      if (!_notifiedStuckDeviceIds.contains(device.deviceId)) {
        _notifiedStuckDeviceIds.add(device.deviceId);
        NotificationService().showStuckNotification(
          deviceId: device.deviceId,
          deviceName: device.currentName,
          tripId: device.activeTripId,
        );
      }
    }

    final activeDevices = <String, DeviceModel>{};
    for (final device in devices) {
      if (device.activeTripId != null && device.activeTripId!.isNotEmpty) {
        activeDevices[device.deviceId] = device;

        if (!_lastSeenLocalTimes.containsKey(device.deviceId)) {
          _lastSeenLocalTimes[device.deviceId] = now;
          if (device.lastSeen != null) {
            _lastSeenValues[device.deviceId] = device.lastSeen!;
          }
        } else {
          final prev = _lastSeenValues[device.deviceId];
          if (device.lastSeen != null && (prev == null || !device.lastSeen!.isAtSameMomentAs(prev))) {
            _lastSeenValues[device.deviceId] = device.lastSeen!;
            _lastSeenLocalTimes[device.deviceId] = now;
            _gatewayLostEpisodeActive.remove(device.deviceId);
            if (_gatewayLostDevices.remove(device.deviceId) != null) {
              NotificationService().cancelStuckNotification(device.deviceId);
            }
          }
        }
      } else {
        _lastSeenLocalTimes.remove(device.deviceId);
        _lastSeenValues.remove(device.deviceId);
        _gatewayLostEpisodeActive.remove(device.deviceId);
        if (_gatewayLostDevices.remove(device.deviceId) != null) {
          NotificationService().cancelStuckNotification(device.deviceId);
        }
      }
    }
    _activeTripDevices
      ..clear()
      ..addAll(activeDevices);

    final resolvedIds = _notifiedStuckDeviceIds
        .difference(currentStuckIds)
        .where((id) => !_gatewayLostDevices.containsKey(id))
        .toList();
    for (final id in resolvedIds) {
      _notifiedStuckDeviceIds.remove(id);
      NotificationService().cancelStuckNotification(id);
    }

    _evaluateState();
  }

  bool _isSilenced(String deviceId) {
    final expire = _silencedUntil[deviceId];
    if (expire == null) return false;
    return DateTime.now().isBefore(expire);
  }

  List<DeviceModel> _getAllStuckDevices() {
    final list = List<DeviceModel>.from(_stuckDevices);
    final stuckIds = list.map((d) => d.deviceId).toSet();
    for (final dev in _gatewayLostDevices.values) {
      if (!stuckIds.contains(dev.deviceId)) {
        list.add(dev);
      }
    }
    return list;
  }

  List<DeviceModel> _getUnsilencedStuckDevices() {
    return _getAllStuckDevices().where((d) => !_isSilenced(d.deviceId)).toList();
  }

  Future<ActiveTripModel?> _lookupActiveTrip(DeviceModel device) async {
    if (_tripService != null) {
      try {
        final trip = await _tripService!.getActiveTripForDevice(device.deviceId);
        if (trip != null) return trip;
      } catch (e) {
        debugPrint('[GlobalAlarmService] Trip lookup error: $e');
      }
    }
    if (device.activeTripId != null && device.activeTripId!.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('activeTrips')
            .doc(device.activeTripId)
            .get();
        if (doc.exists) {
          return ActiveTripModel.fromFirestore(doc);
        }
      } catch (_) {}
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('activeTrips')
          .where('deviceId', isEqualTo: device.deviceId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return ActiveTripModel.fromFirestore(snap.docs.first);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _evaluateState() async {
    if (!_isAuthenticated || _isLoginScreen()) {
      AlarmSoundManager.stop();
      dismissDialog();
      return;
    }

    final unsilenced = _getUnsilencedStuckDevices();

    if (unsilenced.isEmpty) {
      AlarmSoundManager.stop();
      dismissDialog();
      return;
    }

    final nextDevice = unsilenced.first;
    final trip = await _lookupActiveTrip(nextDevice);

    if (!_isAuthenticated || _isLoginScreen()) {
      AlarmSoundManager.stop();
      dismissDialog();
      return;
    }

    final currentUnsilenced = _getUnsilencedStuckDevices();
    if (currentUnsilenced.isEmpty) {
      AlarmSoundManager.stop();
      dismissDialog();
      return;
    }

    final payload = GlobalAlarmPayload(
      device: nextDevice,
      trip: trip,
      totalStuckCount: _getAllStuckDevices().length,
    );

    currentPayload.value = payload;

    if (!_isDialogOpen) {
      _showAlarmDialog();
    } else {
      AlarmSoundManager.start();
    }
  }

  void _showAlarmDialog() {
    if (!_isAuthenticated || _isLoginScreen()) return;
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    _isDialogOpen = true;
    AlarmSoundManager.start();

    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (dialogContext) {
        return ValueListenableBuilder<GlobalAlarmPayload?>(
          valueListenable: currentPayload,
          builder: (ctx, payload, _) {
            if (payload == null) {
              return const SizedBox.shrink();
            }
            return GlobalAlarmDialog(
              device: payload.device,
              trip: payload.trip,
              totalStuckCount: payload.totalStuckCount,
              isNurse: _isNurse(),
              onOpenAlarmScreen: () {
                _handleOpenAlarmScreen(payload.device, payload.trip);
              },
              onSilence60s: () {
                _handleSilenceDevice(payload.device.deviceId);
              },
              onFlowResumed: () {
                _handleFlowResumed(payload.device, payload.trip);
              },
              onInfusionCompleted: () {
                _handleInfusionCompleted(payload.device, payload.trip);
              },
            );
          },
        );
      },
    ).then((_) {
      _isDialogOpen = false;
      AlarmSoundManager.stop();
    });
  }

  String _getNurseName() {
    final context = _navigatorKey?.currentContext;
    if (context == null) return 'Nurse on Duty';
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      return authService.currentUser?.name ?? 'Nurse on Duty';
    } catch (_) {
      return 'Nurse on Duty';
    }
  }

  void _showErrorSnackbar(String message) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleFlowResumed(DeviceModel device, ActiveTripModel? trip) async {
    final effectiveTripId = trip?.tripId ?? device.activeTripId;
    if (effectiveTripId == null || effectiveTripId.isEmpty) {
      _showErrorSnackbar('No active trip found for ${device.currentName}');
      return;
    }
    if (_tripService == null) {
      _showErrorSnackbar('TripService not initialized');
      return;
    }
    final nurseName = _getNurseName();

    try {
      await _tripService!.resumeFlow(
        tripId: effectiveTripId,
        deviceId: device.deviceId,
        nurseIdentifier: nurseName,
      );
      _stuckDevices.removeWhere((d) => d.deviceId == device.deviceId);
      _gatewayLostDevices.remove(device.deviceId);
      _gatewayLostEpisodeActive.remove(device.deviceId);
      _silencedUntil.remove(device.deviceId);
      _notifiedStuckDeviceIds.remove(device.deviceId);
      NotificationService().cancelStuckNotification(device.deviceId);

      dismissDialog();
      await _evaluateState();
    } catch (e) {
      debugPrint('[GlobalAlarmService] Error resuming flow: $e');
      _showErrorSnackbar('Error resuming flow: $e');
    }
  }

  Future<void> _handleInfusionCompleted(DeviceModel device, ActiveTripModel? trip) async {
    final effectiveTripId = trip?.tripId ?? device.activeTripId;
    if (effectiveTripId == null || effectiveTripId.isEmpty) {
      _showErrorSnackbar('No active trip found for ${device.currentName}');
      return;
    }
    if (_tripService == null) {
      _showErrorSnackbar('TripService not initialized');
      return;
    }
    final nurseName = _getNurseName();

    try {
      await _tripService!.completeInfusion(
        tripId: effectiveTripId,
        deviceId: device.deviceId,
        nurseIdentifier: nurseName,
      );
      _stuckDevices.removeWhere((d) => d.deviceId == device.deviceId);
      _gatewayLostDevices.remove(device.deviceId);
      _gatewayLostEpisodeActive.remove(device.deviceId);
      _silencedUntil.remove(device.deviceId);
      _notifiedStuckDeviceIds.remove(device.deviceId);
      NotificationService().cancelStuckNotification(device.deviceId);

      dismissDialog();
      await _evaluateState();
    } catch (e) {
      debugPrint('[GlobalAlarmService] Error completing infusion: $e');
      _showErrorSnackbar('Error completing infusion: $e');
    }
  }

  void _handleSilenceDevice(String deviceId) {
    _silencedUntil[deviceId] = DateTime.now().add(const Duration(seconds: 60));
    final unsilenced = _getUnsilencedStuckDevices();
    if (unsilenced.isEmpty) {
      AlarmSoundManager.stop();
      dismissDialog();
    } else {
      _evaluateState();
    }
  }

  void _handleOpenAlarmScreen(DeviceModel device, ActiveTripModel? trip) {
    _silencedUntil[device.deviceId] = DateTime.now().add(const Duration(seconds: 60));
    AlarmSoundManager.stop();
    dismissDialog();

    _navigatorKey?.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(
          deviceId: device.deviceId,
          tripId: trip?.tripId ?? device.activeTripId,
        ),
      ),
    );
  }
}
