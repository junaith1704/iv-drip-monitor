import 'package:flutter_test/flutter_test.dart';
import 'package:iv_drip_monitor/models/device_model.dart';
import 'package:iv_drip_monitor/models/trip_model.dart';
import 'package:iv_drip_monitor/models/service_request_model.dart';
import 'package:iv_drip_monitor/models/user_model.dart';
import 'package:iv_drip_monitor/services/firebase_service.dart';
import 'package:iv_drip_monitor/services/device_service.dart';
import 'package:iv_drip_monitor/services/trip_service.dart';
import 'package:iv_drip_monitor/services/service_request_service.dart';

void main() {
  setUp(() {
    FirebaseService.setMockFallback(true);
  });

  group('Firestore Models Serialization Tests', () {
    test('DeviceModel correctly serializes and stores nameHistory', () {
      final now = DateTime.now();
      final device = DeviceModel(
        deviceId: 'ESP32_TEST',
        currentName: 'Floor 3 - Bed 301',
        status: 'idle',
        lastUpdated: now,
        nameHistory: [
          NameHistoryEntry(
            name: 'Floor 1 - Triage A',
            from: now.subtract(const Duration(days: 7)),
            to: now,
          ),
        ],
      );

      final map = device.toMap();
      expect(map['deviceId'], 'ESP32_TEST');
      expect(map['currentName'], 'Floor 3 - Bed 301');
      expect((map['nameHistory'] as List).length, 1);

      final recreated = DeviceModel.fromMap(map, 'ESP32_TEST');
      expect(recreated.deviceId, 'ESP32_TEST');
      expect(recreated.currentName, 'Floor 3 - Bed 301');
      expect(recreated.nameHistory.length, 1);
      expect(recreated.nameHistory.first.name, 'Floor 1 - Triage A');
    });

    test('ActiveTripModel and IvTripModel data integrity', () {
      final startTime = DateTime.now().subtract(const Duration(hours: 2));
      final endTime = DateTime.now();

      final activeTrip = ActiveTripModel(
        tripId: 'trip_unit_1',
        deviceId: 'ESP32_01',
        deviceName: 'Bed 1',
        patientName: 'Jane Doe',
        issue: '0.9% Saline IV',
        startTime: startTime,
        status: 'running',
        stoppedEvents: [
          StoppedEvent(
            time: startTime.add(const Duration(minutes: 30)),
            resolvedTime: startTime.add(const Duration(minutes: 35)),
            resolvedBy: 'Nurse Alice',
          ),
        ],
      );

      expect(activeTrip.stoppedEvents.length, 1);
      expect(activeTrip.stoppedEvents.first.isResolved, true);

      final finalizedTrip = IvTripModel(
        tripId: activeTrip.tripId,
        deviceId: activeTrip.deviceId,
        deviceName: activeTrip.deviceName,
        patientName: activeTrip.patientName,
        issue: activeTrip.issue,
        startTime: activeTrip.startTime,
        endTime: endTime,
        stoppedEvents: activeTrip.stoppedEvents,
        completedBy: 'Nurse Alice',
        completedAt: endTime,
      );

      expect(finalizedTrip.totalDuration.inHours, 2);
      expect(finalizedTrip.completedBy, 'Nurse Alice');
    });

    test('ServiceRequestModel read-only preservation', () {
      final now = DateTime.now();
      final request = ServiceRequestModel(
        requestId: 'req_101',
        raisedBy: 'nurse_01',
        raisedByName: 'Nurse Bob',
        deviceId: 'ESP32_02',
        deviceName: 'Bed 2',
        issueText: 'Sensor clamp broken',
        status: 'open',
        raisedAt: now,
      );

      expect(request.isOpen, true);
      expect(request.isResolved, false);

      final resolved = request.copyWith(
        status: 'resolved',
        resolvedAt: now.add(const Duration(hours: 1)),
        resolvedBy: 'Admin Charlie',
      );

      expect(resolved.isResolved, true);
      expect(resolved.issueText, 'Sensor clamp broken'); // Text remains unaltered
      expect(resolved.resolvedBy, 'Admin Charlie');
    });

    test('UserModel role validation', () {
      final nurse = UserModel(
        userId: 'u1',
        name: 'Nurse Nancy',
        email: 'nancy@hospital.org',
        role: 'nurse',
      );
      expect(nurse.isNurse, true);
      expect(nurse.isAdmin, false);

      final admin = UserModel(
        userId: 'u2',
        name: 'Dr. Admin',
        email: 'admin@hospital.org',
        role: 'admin',
      );
      expect(admin.isAdmin, true);
      expect(admin.isNurse, false);
    });
  });

  group('Clinical Service Business Logic Tests', () {
    test('DeviceService rename updates nameHistory with timestamps', () async {
      final deviceService = DeviceService();
      await deviceService.addDevice(deviceId: 'ESP32_UNIT', currentName: 'Room 101');

      var dev = await deviceService.getDevice('ESP32_UNIT');
      expect(dev, isNotNull);
      expect(dev!.currentName, 'Room 101');
      expect(dev.nameHistory.isEmpty, true);

      // Reassign to Room 202
      await deviceService.renameDevice('ESP32_UNIT', 'Room 202');
      dev = await deviceService.getDevice('ESP32_UNIT');

      expect(dev!.currentName, 'Room 202');
      expect(dev.nameHistory.length, 1);
      expect(dev.nameHistory.first.name, 'Room 101');
      expect(dev.nameHistory.first.to, isNotNull);
    });

    test('Complete infusion cycle: start -> stop -> resume -> complete', () async {
      final deviceService = DeviceService();
      final tripService = TripService(deviceService: deviceService);

      await deviceService.addDevice(deviceId: 'ESP32_CYCLE', currentName: 'Station 9');

      // 1. Start trip
      final tripId = await tripService.startTrip(
        deviceId: 'ESP32_CYCLE',
        deviceName: 'Station 9',
        patientName: 'Robert Smith',
        issue: 'Electrolytes',
      );

      var device = await deviceService.getDevice('ESP32_CYCLE');
      expect(device!.isRunning, true);
      expect(device.activeTripId, tripId);

      // 2. Hardware drop sensor stop event
      await tripService.simulateDropStop(deviceId: 'ESP32_CYCLE');
      device = await deviceService.getDevice('ESP32_CYCLE');
      expect(device!.isStuck, true);

      var activeTrip = await tripService.getActiveTripForDevice('ESP32_CYCLE');
      expect(activeTrip!.isStuck, true);
      expect(activeTrip.stoppedEvents.length, 1);
      expect(activeTrip.stoppedEvents.first.isResolved, false);

      // 3. Nurse taps "Flow Resumed"
      await tripService.resumeFlow(
        tripId: tripId,
        deviceId: 'ESP32_CYCLE',
        nurseIdentifier: 'Nurse Florence',
      );
      device = await deviceService.getDevice('ESP32_CYCLE');
      expect(device!.isRunning, true);

      activeTrip = await tripService.getActiveTripForDevice('ESP32_CYCLE');
      expect(activeTrip!.isRunning, true);
      expect(activeTrip.stoppedEvents.first.isResolved, true);
      expect(activeTrip.stoppedEvents.first.resolvedBy, 'Nurse Florence');

      // 4. Nurse taps "Infusion Completed"
      await tripService.completeInfusion(
        tripId: tripId,
        deviceId: 'ESP32_CYCLE',
        nurseIdentifier: 'Nurse Florence',
      );

      device = await deviceService.getDevice('ESP32_CYCLE');
      expect(device!.isIdle, true);
      expect(device.activeTripId, isNull);

      final remainingActive = await tripService.getActiveTripForDevice('ESP32_CYCLE');
      expect(remainingActive, isNull);
    });

    test('ServiceRequestService nurse submit and admin resolve flow', () async {
      final reqService = ServiceRequestService();

      await reqService.submitRequest(
        raisedBy: 'nurse_test_9',
        raisedByName: 'Nurse Test',
        deviceId: 'ESP32_01',
        deviceName: 'Floor 2 - Bed 101',
        issueText: 'Battery indicator flashing red',
      );

      final nurseStream = reqService.streamNurseRequests('nurse_test_9');
      final requests = await nurseStream.first;
      expect(requests.any((r) => r.issueText == 'Battery indicator flashing red'), true);

      final openTicket = requests.firstWhere((r) => r.issueText == 'Battery indicator flashing red');
      expect(openTicket.isOpen, true);

      // Admin resolves ticket
      await reqService.resolveRequest(
        requestId: openTicket.requestId,
        resolvedBy: 'Dr. Vance (Admin)',
      );

      final openQueue = await reqService.streamOpenRequests().first;
      // Must disappear from open queue per spec
      expect(openQueue.any((r) => r.requestId == openTicket.requestId), false);
    });
  });
}
