import 'package:cloud_firestore/cloud_firestore.dart';

class StoppedEvent {
  final DateTime time;
  final DateTime? resolvedTime;
  final String? resolvedBy;

  StoppedEvent({
    required this.time,
    this.resolvedTime,
    this.resolvedBy,
  });

  bool get isResolved => resolvedTime != null;

  factory StoppedEvent.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return StoppedEvent(
      time: parseDate(map['time']),
      resolvedTime: map['resolvedTime'] != null ? parseDate(map['resolvedTime']) : null,
      resolvedBy: map['resolvedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': Timestamp.fromDate(time),
      if (resolvedTime != null) 'resolvedTime': Timestamp.fromDate(resolvedTime!),
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
    };
  }
}

class ActiveTripModel {
  final String tripId;
  final String deviceId;
  final String deviceName;
  final String patientName;
  final String issue;
  final DateTime startTime;
  final List<StoppedEvent> stoppedEvents;
  final String status; // 'running' | 'stuck'

  ActiveTripModel({
    required this.tripId,
    required this.deviceId,
    required this.deviceName,
    required this.patientName,
    required this.issue,
    required this.startTime,
    this.stoppedEvents = const [],
    this.status = 'running',
  });

  bool get isStuck => status == 'stuck';
  bool get isRunning => status == 'running';

  factory ActiveTripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ActiveTripModel.fromMap(data, doc.id);
  }

  factory ActiveTripModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawEvents = map['stoppedEvents'] as List<dynamic>? ?? [];
    final events = rawEvents
        .map((e) => StoppedEvent.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return ActiveTripModel(
      tripId: id ?? map['tripId'] as String? ?? '',
      deviceId: map['deviceId'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? 'Device',
      patientName: map['patientName'] as String? ?? 'Unknown Patient',
      issue: map['issue'] as String? ?? '',
      startTime: parseDate(map['startTime']),
      stoppedEvents: events,
      status: map['status'] as String? ?? 'running',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'patientName': patientName,
      'issue': issue,
      'startTime': Timestamp.fromDate(startTime),
      'stoppedEvents': stoppedEvents.map((e) => e.toMap()).toList(),
      'status': status,
    };
  }

  ActiveTripModel copyWith({
    String? tripId,
    String? deviceId,
    String? deviceName,
    String? patientName,
    String? issue,
    DateTime? startTime,
    List<StoppedEvent>? stoppedEvents,
    String? status,
  }) {
    return ActiveTripModel(
      tripId: tripId ?? this.tripId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      patientName: patientName ?? this.patientName,
      issue: issue ?? this.issue,
      startTime: startTime ?? this.startTime,
      stoppedEvents: stoppedEvents ?? this.stoppedEvents,
      status: status ?? this.status,
    );
  }
}

class IvTripModel {
  final String tripId;
  final String deviceId;
  final String deviceName;
  final String patientName;
  final String issue;
  final DateTime startTime;
  final DateTime endTime;
  final List<StoppedEvent> stoppedEvents;
  final String completedBy;
  final DateTime completedAt;

  IvTripModel({
    required this.tripId,
    required this.deviceId,
    required this.deviceName,
    required this.patientName,
    required this.issue,
    required this.startTime,
    required this.endTime,
    this.stoppedEvents = const [],
    required this.completedBy,
    required this.completedAt,
  });

  Duration get totalDuration => endTime.difference(startTime);

  factory IvTripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return IvTripModel.fromMap(data, doc.id);
  }

  factory IvTripModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawEvents = map['stoppedEvents'] as List<dynamic>? ?? [];
    final events = rawEvents
        .map((e) => StoppedEvent.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return IvTripModel(
      tripId: id ?? map['tripId'] as String? ?? '',
      deviceId: map['deviceId'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? 'Device',
      patientName: map['patientName'] as String? ?? 'Unknown Patient',
      issue: map['issue'] as String? ?? '',
      startTime: parseDate(map['startTime']),
      endTime: parseDate(map['endTime']),
      stoppedEvents: events,
      completedBy: map['completedBy'] as String? ?? '',
      completedAt: parseDate(map['completedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'patientName': patientName,
      'issue': issue,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'stoppedEvents': stoppedEvents.map((e) => e.toMap()).toList(),
      'completedBy': completedBy,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }
}
