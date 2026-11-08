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

  final List<ActiveTripModel> _mockActiveTrips = [];

  final List<IvTripModel> _mockCompletedTrips = [];

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

    return _firestore.collection('activeTrips').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ActiveTripModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<IvTripModel>> streamCompletedTrips() {
    if (FirebaseService.isMockFallback) {
      return _completedTripsController.stream.asBroadcastStream(
        onListen: (sub) => _completedTripsController.add(List.unmodifiable(_mockCompletedTrips)),
      );
    }

    return _firestore
        .collection('ivTrips')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => IvTripModel.fromFirestore(doc)).toList();
    });
  }

  Future<ActiveTripModel?> getActiveTripForDevice(String deviceId) async {
    if (FirebaseService.isMockFallback) {
      try {
        return _mockActiveTrips.firstWhere((t) => t.deviceId == deviceId);
      } catch (_) {
        return null;
      }
    }

    final snap = await _firestore
        .collection('activeTrips')
        .where('deviceId', isEqualTo: deviceId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return null;
    }
    return ActiveTripModel.fromFirestore(snap.docs.first);
  }

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

    await _firestore.collection('activeTrips').doc(tripId).set(newTrip.toMap());
    await deviceService.updateDeviceStatus(deviceId, 'running', activeTripId: tripId);

    notifyListeners();
    return tripId;
  }

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

    await _firestore.collection('activeTrips').doc(trip.tripId).update({
      'status': 'stuck',
      'stoppedEvents': updatedEvents.map((e) => e.toMap()).toList(),
    });
    await deviceService.updateDeviceStatus(deviceId, 'stuck', activeTripId: trip.tripId);
    notifyListeners();
  }

  Future<void> resumeFlow({
    required String tripId,
    required String deviceId,
    required String nurseIdentifier,
  }) async {
    final now = DateTime.now();

    if (FirebaseService.isMockFallback) {
      final index = _mockActiveTrips.indexWhere((t) => t.tripId == tripId);
      if (index == -1) {
        throw Exception('Trip not found. Refresh and try again.');
      }
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
      await deviceService.updateDeviceStatus(deviceId, 'running', activeTripId: tripId);
      notifyListeners();
      return;
    }

    final docRef = _firestore.collection('activeTrips').doc(tripId);
    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception('Trip not found. Refresh and try again.');
    }
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
    notifyListeners();
  }

  Future<void> completeInfusion({
    required String tripId,
    required String deviceId,
    required String nurseIdentifier,
  }) async {
    final now = DateTime.now();

    ActiveTripModel currentTrip;
    if (FirebaseService.isMockFallback) {
      try {
        currentTrip = _mockActiveTrips.firstWhere((t) => t.tripId == tripId);
      } catch (_) {
        throw Exception('Trip not found. Refresh and try again.');
      }
    } else {
      final doc = await _firestore.collection('activeTrips').doc(tripId).get();
      if (!doc.exists) {
        throw Exception('Trip not found. Refresh and try again.');
      }
      currentTrip = ActiveTripModel.fromFirestore(doc);
    }

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

    final batch = _firestore.batch();
    batch.set(_firestore.collection('ivTrips').doc(tripId), completedTrip.toMap());
    batch.delete(_firestore.collection('activeTrips').doc(tripId));
    batch.update(_firestore.collection('devices').doc(deviceId), {
      'status': 'idle',
      'activeTripId': null,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    notifyListeners();
  }

  @override
  void dispose() {
    _activeTripsController.close();
    _completedTripsController.close();
    super.dispose();
  }
}
