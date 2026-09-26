import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/trip_model.dart';
import 'device_service.dart';
import 'firebase_service.dart';

class TripService extends ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final DeviceService deviceService;
  final _uuid = const Uuid();

  // In-memory fallback mock active trips
  final List<ActiveTripModel> _mockActiveTrips = [
    ActiveTripModel(
      tripId: 'trip_1001',
      deviceId: 'ESP32_02',
      deviceName: 'Floor 2 - Bed 102',
      patientName: 'Eleanor Roosevelt',
      issue: 'Post-op Hydration & Electrolytes',
      startTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
      status: 'running',
      stoppedEvents: [],
    ),
    ActiveTripModel(
      tripId: 'trip_1002',
      deviceId: 'ESP32_03',
      deviceName: 'Floor 2 - Bed 105',
      patientName: 'Arthur Pendelton',
      issue: 'Antibiotic Infusion (Vancomycin)',
      startTime: DateTime.now().subtract(const Duration(minutes: 50)),
      status: 'stuck',
      stoppedEvents: [
        StoppedEvent(
          time: DateTime.now().subtract(const Duration(minutes: 6)),
        ),
      ],
    ),
  ];

  // In-memory fallback mock finalized ivTrips
  final List<IvTripModel> _mockCompletedTrips = [
    IvTripModel(
      tripId: 'trip_0980',
      deviceId: 'ESP32_01',
      deviceName: 'Floor 2 - Bed 101',
      patientName: 'Margaret Thatcher',
      issue: 'Saline 0.9% Maintenance',
      startTime: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      endTime: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
      stoppedEvents: [
        StoppedEvent(
          time: DateTime.now().subtract(const Duration(days: 1, hours: 2, minutes: 40)),
          resolvedTime: DateTime.now().subtract(const Duration(days: 1, hours: 2, minutes: 35)),
          resolvedBy: 'Nurse Sarah Jenkins, RN',
        ),
      ],
      completedBy: 'Nurse Sarah Jenkins, RN',
      completedAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
    ),
    IvTripModel(
      tripId: 'trip_0975',
      deviceId: 'ESP32_04',
      deviceName: 'Floor 1 - Emergency 02',
      patientName: 'James Wilson',
      issue: 'Ringer Lactate Infusion',
      startTime: DateTime.now().subtract(const Duration(days: 2, hours: 8)),
      endTime: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
      stoppedEvents: [],
      completedBy: 'Nurse David Chen, BSN',
      completedAt: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
    ),
  ];

  final StreamController<List<ActiveTripModel>> _activeTripsController =
      StreamController<List<ActiveTripModel>>.broadcast();

  final StreamController<List<IvTripModel>> _completedTripsController =
      StreamController<List<IvTripModel>>.broadcast();

  TripService({required this.deviceService}) {
    _activeTripsController.add(List.unmodifiable(_mockActiveTrips));
    _completedTripsController.add(List.unmodifiable(_mockCompletedTrips));
  }

  Stream<List<ActiveTripModel>> streamActiveTrips() {
    if (FirebaseService.isMockFallback) {
      return _activeTripsController.stream.asBroadcastStream(
        onListen: (sub) => _activeTripsController.add(List.unmodifiable(_mockActiveTrips)),
      );
    }

    try {
      return _firestore.collection('activeTrips').snapshots().map((snapshot) {
        if (snapshot.docs.isEmpty) return _mockActiveTrips;
        return snapshot.docs.map((doc) => ActiveTripModel.fromFirestore(doc)).toList();
      });
    } catch (e) {
      debugPrint('[TripService] streamActiveTrips error: $e');
      return _activeTripsController.stream;
    }
  }

  Stream<List<IvTripModel>> streamCompletedTrips() {
    if (FirebaseService.isMockFallback) {
      return _completedTripsController.stream.asBroadcastStream(
        onListen: (sub) => _completedTripsController.add(List.unmodifiable(_mockCompletedTrips)),
      );
    }

    try {
      return _firestore
          .collection('ivTrips')
          .orderBy('completedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) return _mockCompletedTrips;
        return snapshot.docs.map((doc) => IvTripModel.fromFirestore(doc)).toList();
      });
    } catch (e) {
      debugPrint('[TripService] streamCompletedTrips error: $e');
      return _completedTripsController.stream;
    }
  }

  Future<ActiveTripModel?> getActiveTripForDevice(String deviceId) async {
    if (FirebaseService.isMockFallback) {
      try {
        return _mockActiveTrips.firstWhere((t) => t.deviceId == deviceId);
      } catch (_) {
        return null;
      }
    }

    try {
      final snap = await _firestore
          .collection('activeTrips')
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        try {
          return _mockActiveTrips.firstWhere((t) => t.deviceId == deviceId);
        } catch (_) {
          return null;
        }
      }
      return ActiveTripModel.fromFirestore(snap.docs.first);
    } catch (e) {
      try {
        return _mockActiveTrips.firstWhere((t) => t.deviceId == deviceId);
      } catch (_) {
        return null;
      }
    }
  }

  /// Start a new infusion trip: creates activeTrip and marks device as running
  Future<String> startTrip({
    required String deviceId,
    required String deviceName,
    required String patientName,
    required String issue,
  }) async {
    final tripId = 'trip_${_uuid.v4().substring(0, 8)}';
    final now = DateTime.now();

    final newTrip = ActiveTripModel(
      tripId: tripId,
      deviceId: deviceId,
      deviceName: deviceName,
      patientName: patientName,
      issue: issue,
      startTime: now,
      status: 'running',
      stoppedEvents: [],
    );

    if (FirebaseService.isMockFallback) {
      _mockActiveTrips.add(newTrip);
      _activeTripsController.add(List.unmodifiable(_mockActiveTrips));
      await deviceService.updateDeviceStatus(deviceId, 'running', activeTripId: tripId);
      notifyListeners();
      return tripId;
    }

    try {
      await _firestore.collection('activeTrips').doc(tripId).set(newTrip.toMap());
      await deviceService.updateDeviceStatus(deviceId, 'running', activeTripId: tripId);
    } catch (e) {
      debugPrint('[TripService] startTrip error: $e');
      _mockActiveTrips.add(newTrip);
      _activeTripsController.add(List.unmodifiable(_mockActiveTrips));
      await deviceService.updateDeviceStatus(deviceId, 'running', activeTripId: tripId);
    }

    notifyListeners();
    return tripId;
  }

  /// Simulate hardware (ESP32-C3) drop stoppage
  Future<void> simulateDropStop({required String deviceId}) async {
    final trip = await getActiveTripForDevice(deviceId);
    if (trip == null) return;

    final now = DateTime.now();
    final updatedEvents = List<StoppedEvent>.from(trip.stoppedEvents)
      ..add(StoppedEvent(time: now));

    if (FirebaseService.isMockFallback) {
      final index = _mockActiveTrips.indexWhere((t) => t.tripId == trip.tripId);
      if (index != -1) {
        _mockActiveTrips[index] = trip.copyWith(
          status: 'stuck',
          stoppedEvents: updatedEvents,
        );
        _activeTripsController.add(List.unmodifiable(_mockActiveTrips));
      }
      await deviceService.updateDeviceStatus(deviceId, 'stuck', activeTripId: trip.tripId);
      notifyListeners();
      return;
    }

    try {
      await _firestore.collection('activeTrips').doc(trip.tripId).update({
        'status': 'stuck',
        'stoppedEvents': updatedEvents.map((e) => e.toMap()).toList(),
      });
      await deviceService.updateDeviceStatus(deviceId, 'stuck', activeTripId: trip.tripId);
    } catch (e) {
      debugPrint('[TripService] simulateDropStop error: $e');
    }
  }

  /// Nurse taps "Flow Resumed" on Alarm screen
  Future<void> resumeFlow({
    required String tripId,
    required String deviceId,
    required String nurseIdentifier,
  }) async {
    final now = DateTime.now();

    if (FirebaseService.isMockFallback) {
      final index = _mockActiveTrips.indexWhere((t) => t.tripId == tripId);
      if (index != -1) {
        final current = _mockActiveTrips[index];
        final updatedEvents = current.stoppedEvents.map((e) {
          if (!e.isResolved) {
            return StoppedEvent(
              time: e.time,
              resolvedTime: now,
              resolvedBy: nurseIdentifier,
            );
          }
          return e;
        }).toList();

        _mockActiveTrips[index] = current.copyWith(
          status: 'running',
          stoppedEvents: updatedEvents,
        );
        _activeTripsController.add(List.unmodifiable(_mockActiveTrips));
      }
      await deviceService.updateDeviceStatus(deviceId, 'running', activeTripId: tripId);
      notifyListeners();
      return;
    }

    try {
      final docRef = _firestore.collection('activeTrips').doc(tripId);
      final doc = await docRef.get();
      if (doc.exists) {
        final current = ActiveTripModel.fromFirestore(doc);
        final updatedEvents = current.stoppedEvents.map((e) {
          if (!e.isResolved) {
            return StoppedEvent(
              time: e.time,
              resolvedTime: now,
              resolvedBy: nurseIdentifier,
            );
          }
          return e;
        }).toList();

        await docRef.update({
          'status': 'running',
          'stoppedEvents': updatedEvents.map((e) => e.toMap()).toList(),
        });
        await deviceService.updateDeviceStatus(deviceId, 'running', activeTripId: tripId);
      }
    } catch (e) {
      debugPrint('[TripService] resumeFlow error: $e');
    }
    notifyListeners();
  }

  /// Nurse taps "Infusion Completed":
  /// Writes finalized record ONLY to ivTrips, removes from activeTrips, sets device to idle
  Future<void> completeInfusion({
    required String tripId,
    required String deviceId,
    required String nurseIdentifier,
  }) async {
    final now = DateTime.now();

    ActiveTripModel? currentTrip;
    if (FirebaseService.isMockFallback) {
      try {
        currentTrip = _mockActiveTrips.firstWhere((t) => t.tripId == tripId);
      } catch (_) {}
    } else {
      try {
        final doc = await _firestore.collection('activeTrips').doc(tripId).get();
        if (doc.exists) {
          currentTrip = ActiveTripModel.fromFirestore(doc);
        }
      } catch (_) {}
    }

    // Default fallback trip if not found
    currentTrip ??= ActiveTripModel(
      tripId: tripId,
      deviceId: deviceId,
      deviceName: 'Device',
      patientName: 'Patient',
      issue: 'Infusion complete',
      startTime: now.subtract(const Duration(hours: 1)),
      status: 'running',
      stoppedEvents: [],
    );

    // Resolve any pending stop event
    final finalizedEvents = currentTrip.stoppedEvents.map((e) {
      if (!e.isResolved) {
        return StoppedEvent(
          time: e.time,
          resolvedTime: now,
          resolvedBy: nurseIdentifier,
        );
      }
      return e;
    }).toList();

    // Snapshot current device name
    final device = await deviceService.getDevice(deviceId);
    final snapshotDeviceName = device?.currentName ?? currentTrip.deviceName;

    final completedTrip = IvTripModel(
      tripId: currentTrip.tripId,
      deviceId: deviceId,
      deviceName: snapshotDeviceName,
      patientName: currentTrip.patientName,
      issue: currentTrip.issue,
      startTime: currentTrip.startTime,
      endTime: now,
      stoppedEvents: finalizedEvents,
      completedBy: nurseIdentifier,
      completedAt: now,
    );

    if (FirebaseService.isMockFallback) {
      _mockActiveTrips.removeWhere((t) => t.tripId == tripId);
      _mockCompletedTrips.insert(0, completedTrip);
      _activeTripsController.add(List.unmodifiable(_mockActiveTrips));
      _completedTripsController.add(List.unmodifiable(_mockCompletedTrips));
      await deviceService.updateDeviceStatus(deviceId, 'idle', activeTripId: null);
      notifyListeners();
      return;
    }

    try {
      // 1. Write finalized record to ivTrips
      await _firestore.collection('ivTrips').doc(tripId).set(completedTrip.toMap());

      // 2. Remove from activeTrips
      await _firestore.collection('activeTrips').doc(tripId).delete();

      // 3. Set device to idle
      await deviceService.updateDeviceStatus(deviceId, 'idle', activeTripId: null);
    } catch (e) {
      debugPrint('[TripService] completeInfusion error: $e');
      _mockActiveTrips.removeWhere((t) => t.tripId == tripId);
      _mockCompletedTrips.insert(0, completedTrip);
      _activeTripsController.add(List.unmodifiable(_mockActiveTrips));
      _completedTripsController.add(List.unmodifiable(_mockCompletedTrips));
      await deviceService.updateDeviceStatus(deviceId, 'idle', activeTripId: null);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _activeTripsController.close();
    _completedTripsController.close();
    super.dispose();
  }
}
