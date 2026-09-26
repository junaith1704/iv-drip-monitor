import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';
import 'firebase_service.dart';

class DeviceService extends ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // In-memory fallback mock devices with clinical names and history
  final List<DeviceModel> _mockDevices = [
    DeviceModel(
      deviceId: 'ESP32_01',
      currentName: 'Floor 2 - Bed 101',
      status: 'idle',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 4)),
      nameHistory: [
        NameHistoryEntry(
          name: 'Floor 1 - Triage A',
          from: DateTime.now().subtract(const Duration(days: 30)),
          to: DateTime.now().subtract(const Duration(days: 12)),
        ),
        NameHistoryEntry(
          name: 'Floor 2 - Bed 104',
          from: DateTime.now().subtract(const Duration(days: 12)),
          to: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ],
    ),
    DeviceModel(
      deviceId: 'ESP32_02',
      currentName: 'Floor 2 - Bed 102',
      status: 'running',
      activeTripId: 'trip_1001',
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 24)),
      nameHistory: [
        NameHistoryEntry(
          name: 'Floor 3 - ICU 03',
          from: DateTime.now().subtract(const Duration(days: 60)),
          to: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ],
    ),
    DeviceModel(
      deviceId: 'ESP32_03',
      currentName: 'Floor 2 - Bed 105',
      status: 'stuck',
      activeTripId: 'trip_1002',
      lastUpdated: DateTime.now().subtract(const Duration(minutes: 3)),
      nameHistory: [],
    ),
    DeviceModel(
      deviceId: 'ESP32_04',
      currentName: 'Floor 1 - Emergency 02',
      status: 'idle',
      lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
      nameHistory: [],
    ),
  ];

  final StreamController<List<DeviceModel>> _mockStreamController =
      StreamController<List<DeviceModel>>.broadcast();

  DeviceService() {
    _mockStreamController.add(List.unmodifiable(_mockDevices));
  }

  Stream<List<DeviceModel>> streamDevices() {
    if (FirebaseService.isMockFallback) {
      // Return stream from mock controller seeded with initial state
      return _mockStreamController.stream.asBroadcastStream(
        onListen: (sub) {
          _mockStreamController.add(List.unmodifiable(_mockDevices));
        },
      );
    }

    try {
      return _firestore.collection('devices').snapshots().map((snapshot) {
        if (snapshot.docs.isEmpty) {
          _seedInitialDevicesInFirestore();
          return _mockDevices;
        }
        return snapshot.docs.map((doc) => DeviceModel.fromFirestore(doc)).toList();
      });
    } catch (e) {
      debugPrint('[DeviceService] streamDevices error: $e. Falling back to in-memory store.');
      return _mockStreamController.stream;
    }
  }

  Future<void> _seedInitialDevicesInFirestore() async {
    try {
      for (final device in _mockDevices) {
        await _firestore.collection('devices').doc(device.deviceId).set(device.toMap());
      }
    } catch (e) {
      debugPrint('[DeviceService] Seed error: $e');
    }
  }

  Future<DeviceModel?> getDevice(String deviceId) async {
    if (FirebaseService.isMockFallback) {
      try {
        return _mockDevices.firstWhere((d) => d.deviceId == deviceId);
      } catch (_) {
        return null;
      }
    }

    try {
      final doc = await _firestore.collection('devices').doc(deviceId).get();
      if (!doc.exists) return null;
      return DeviceModel.fromFirestore(doc);
    } catch (e) {
      try {
        return _mockDevices.firstWhere((d) => d.deviceId == deviceId);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> addDevice({
    required String deviceId,
    required String currentName,
  }) async {
    final now = DateTime.now();
    final newDevice = DeviceModel(
      deviceId: deviceId,
      currentName: currentName,
      status: 'idle',
      lastUpdated: now,
      nameHistory: [],
    );

    if (FirebaseService.isMockFallback) {
      _mockDevices.removeWhere((d) => d.deviceId == deviceId);
      _mockDevices.add(newDevice);
      _mockStreamController.add(List.unmodifiable(_mockDevices));
      notifyListeners();
      return;
    }

    try {
      await _firestore.collection('devices').doc(deviceId).set(newDevice.toMap());
    } catch (e) {
      _mockDevices.add(newDevice);
      _mockStreamController.add(List.unmodifiable(_mockDevices));
      notifyListeners();
    }
  }

  /// Rename a device (with floor reassignment) and record previous name into nameHistory array
  Future<void> renameDevice(String deviceId, String newName) async {
    final now = DateTime.now();

    if (FirebaseService.isMockFallback) {
      final index = _mockDevices.indexWhere((d) => d.deviceId == deviceId);
      if (index != -1) {
        final current = _mockDevices[index];
        final updatedHistory = List<NameHistoryEntry>.from(current.nameHistory);
        // Record previous name from its last update or default to past date
        final fromDate = current.lastUpdated ?? now.subtract(const Duration(days: 7));
        updatedHistory.add(
          NameHistoryEntry(
            name: current.currentName,
            from: fromDate,
            to: now,
          ),
        );

        _mockDevices[index] = current.copyWith(
          currentName: newName,
          nameHistory: updatedHistory,
          lastUpdated: now,
        );
        _mockStreamController.add(List.unmodifiable(_mockDevices));
        notifyListeners();
      }
      return;
    }

    try {
      final docRef = _firestore.collection('devices').doc(deviceId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final current = DeviceModel.fromFirestore(doc);
      final updatedHistory = List<NameHistoryEntry>.from(current.nameHistory);
      final fromDate = current.lastUpdated ?? now.subtract(const Duration(days: 7));
      updatedHistory.add(
        NameHistoryEntry(
          name: current.currentName,
          from: fromDate,
          to: now,
        ),
      );

      await docRef.update({
        'currentName': newName,
        'nameHistory': updatedHistory.map((e) => e.toMap()).toList(),
        'lastUpdated': Timestamp.fromDate(now),
      });
    } catch (e) {
      debugPrint('[DeviceService] renameDevice error: $e');
    }
  }

  Future<void> updateDeviceStatus(String deviceId, String status, {String? activeTripId}) async {
    final now = DateTime.now();

    if (FirebaseService.isMockFallback) {
      final index = _mockDevices.indexWhere((d) => d.deviceId == deviceId);
      if (index != -1) {
        final current = _mockDevices[index];
        _mockDevices[index] = current.copyWith(
          status: status,
          activeTripId: activeTripId,
          clearActiveTrip: status == 'idle' || activeTripId == null,
          lastUpdated: now,
        );
        _mockStreamController.add(List.unmodifiable(_mockDevices));
        notifyListeners();
      }
      return;
    }

    try {
      final updates = <String, dynamic>{
        'status': status,
        'lastUpdated': Timestamp.fromDate(now),
      };
      if (activeTripId != null) {
        updates['activeTripId'] = activeTripId;
      } else if (status == 'idle') {
        updates['activeTripId'] = null;
      }
      await _firestore.collection('devices').doc(deviceId).update(updates);
    } catch (e) {
      debugPrint('[DeviceService] updateDeviceStatus error: $e');
    }
  }

  @override
  void dispose() {
    _mockStreamController.close();
    super.dispose();
  }
}
