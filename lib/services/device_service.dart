import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';
import 'firebase_service.dart';

class DeviceService extends ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  final List<DeviceModel> _mockDevices = [];

  final StreamController<List<DeviceModel>> _mockStreamController =
      StreamController<List<DeviceModel>>.broadcast();

  DeviceService() {
    _mockStreamController.add(List.unmodifiable(_mockDevices));
  }

  Stream<List<DeviceModel>> streamDevices() {
    if (FirebaseService.isMockFallback) {
      return _mockStreamController.stream.asBroadcastStream(
        onListen: (sub) {
          _mockStreamController.add(List.unmodifiable(_mockDevices));
        },
      );
    }

    return _firestore.collection('devices').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DeviceModel.fromFirestore(doc)).toList();
    });
  }

  Future<DeviceModel?> getDevice(String deviceId) async {
    if (FirebaseService.isMockFallback) {
      try {
        return _mockDevices.firstWhere((d) => d.deviceId == deviceId);
      } catch (_) {
        return null;
      }
    }

    final doc = await _firestore.collection('devices').doc(deviceId).get();
    if (!doc.exists) return null;
    return DeviceModel.fromFirestore(doc);
  }

  Future<void> addDevice({
    required String deviceId,
    required String currentName,
    String? boardIp,
  }) async {
    final cleanIp = (boardIp == null || boardIp.trim().isEmpty) ? null : boardIp.trim();
    final now = DateTime.now();

    if (FirebaseService.isMockFallback) {
      final index = _mockDevices.indexWhere((d) => d.deviceId == deviceId);
      if (index != -1) {
        final existing = _mockDevices[index];
        _mockDevices[index] = existing.copyWith(
          currentName: currentName,
          boardIp: cleanIp,
          clearBoardIp: cleanIp == null,
          lastUpdated: now,
        );
      } else {
        _mockDevices.add(DeviceModel(
          deviceId: deviceId,
          currentName: currentName,
          boardIp: cleanIp,
          status: 'idle',
          lastUpdated: now,
          nameHistory: [],
        ));
      }
      _mockStreamController.add(List.unmodifiable(_mockDevices));
      notifyListeners();
      return;
    }

    final docRef = _firestore.collection('devices').doc(deviceId);
    final doc = await docRef.get();
    if (doc.exists) {
      final updates = <String, dynamic>{
        'currentName': currentName,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (cleanIp != null) {
        updates['boardIp'] = cleanIp;
      } else {
        updates['boardIp'] = FieldValue.delete();
      }
      await docRef.update(updates);
    } else {
      final data = <String, dynamic>{
        'deviceId': deviceId,
        'currentName': currentName,
        'nameHistory': [],
        'status': 'idle',
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (cleanIp != null) {
        data['boardIp'] = cleanIp;
      }
      await docRef.set(data, SetOptions(merge: true));
    }
  }

  Future<void> updateDeviceSettings({
    required String deviceId,
    required String newName,
    String? boardIp,
  }) async {
    final cleanIp = (boardIp == null || boardIp.trim().isEmpty) ? null : boardIp.trim();
    final now = DateTime.now();

    if (FirebaseService.isMockFallback) {
      final index = _mockDevices.indexWhere((d) => d.deviceId == deviceId);
      if (index != -1) {
        final current = _mockDevices[index];
        List<NameHistoryEntry> updatedHistory = current.nameHistory;
        if (newName != current.currentName) {
          updatedHistory = List<NameHistoryEntry>.from(current.nameHistory);
          final fromDate = current.lastUpdated ?? now.subtract(const Duration(days: 7));
          updatedHistory.add(
            NameHistoryEntry(
              name: current.currentName,
              from: fromDate,
              to: now,
            ),
          );
        }

        _mockDevices[index] = current.copyWith(
          currentName: newName,
          boardIp: cleanIp,
          clearBoardIp: cleanIp == null,
          nameHistory: updatedHistory,
          lastUpdated: now,
        );
        _mockStreamController.add(List.unmodifiable(_mockDevices));
        notifyListeners();
      }
      return;
    }

    final docRef = _firestore.collection('devices').doc(deviceId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final current = DeviceModel.fromFirestore(doc);
    final updates = <String, dynamic>{
      'currentName': newName,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (cleanIp != null) {
      updates['boardIp'] = cleanIp;
    } else {
      updates['boardIp'] = FieldValue.delete();
    }

    if (newName != current.currentName) {
      final updatedHistory = List<NameHistoryEntry>.from(current.nameHistory);
      final fromDate = current.lastUpdated ?? now.subtract(const Duration(days: 7));
      updatedHistory.add(
        NameHistoryEntry(
          name: current.currentName,
          from: fromDate,
          to: now,
        ),
      );
      updates['nameHistory'] = updatedHistory.map((e) => e.toMap()).toList();
    }

    await docRef.update(updates);
  }

  Future<void> renameDevice(String deviceId, String newName) async {
    await updateDeviceSettings(deviceId: deviceId, newName: newName);
  }

  Future<void> deleteDevice(String deviceId) async {
    if (FirebaseService.isMockFallback) {
      _mockDevices.removeWhere((d) => d.deviceId == deviceId);
      _mockStreamController.add(List.unmodifiable(_mockDevices));
      notifyListeners();
      return;
    }

    await _firestore.collection('devices').doc(deviceId).delete();
  }

  Future<void> updateDeviceStatus(
    String deviceId,
    String status, {
    String? activeTripId,
    String? alarmReason,
  }) async {
    final now = DateTime.now();

    if (FirebaseService.isMockFallback) {
      final index = _mockDevices.indexWhere((d) => d.deviceId == deviceId);
      if (index != -1) {
        final current = _mockDevices[index];
        _mockDevices[index] = current.copyWith(
          status: status,
          activeTripId: activeTripId,
          clearActiveTrip: status == 'idle' || activeTripId == null,
          alarmReason: alarmReason,
          clearAlarmReason: status == 'running' || status == 'idle',
          lastUpdated: now,
        );
        _mockStreamController.add(List.unmodifiable(_mockDevices));
        notifyListeners();
      }
      return;
    }

    final updates = <String, dynamic>{
      'status': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    if (activeTripId != null) {
      updates['activeTripId'] = activeTripId;
    } else if (status == 'idle') {
      updates['activeTripId'] = null;
    }
    if (alarmReason != null) {
      updates['alarmReason'] = alarmReason;
    } else if (status == 'running' || status == 'idle') {
      updates['alarmReason'] = FieldValue.delete();
    }
    await _firestore.collection('devices').doc(deviceId).update(updates);
  }

  @override
  void dispose() {
    _mockStreamController.close();
    super.dispose();
  }
}
