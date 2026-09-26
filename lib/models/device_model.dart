import 'package:cloud_firestore/cloud_firestore.dart';

class NameHistoryEntry {
  final String name;
  final DateTime from;
  final DateTime? to;

  NameHistoryEntry({
    required this.name,
    required this.from,
    this.to,
  });

  factory NameHistoryEntry.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return NameHistoryEntry(
      name: map['name'] as String? ?? 'Unnamed',
      from: parseDate(map['from']),
      to: map['to'] != null ? parseDate(map['to']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'from': Timestamp.fromDate(from),
      if (to != null) 'to': Timestamp.fromDate(to!),
    };
  }
}

class DeviceModel {
  final String deviceId;
  final String currentName;
  final List<NameHistoryEntry> nameHistory;
  final String status; // 'idle' | 'running' | 'stuck' | 'alarm'
  final String? activeTripId;
  final DateTime? lastUpdated;

  DeviceModel({
    required this.deviceId,
    required this.currentName,
    this.nameHistory = const [],
    this.status = 'idle',
    this.activeTripId,
    this.lastUpdated,
  });

  bool get isRunning => status == 'running';
  bool get isStuck => status == 'stuck';
  bool get isAlarm => status == 'alarm';
  bool get isIdle => status == 'idle';

  factory DeviceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DeviceModel.fromMap(data, doc.id);
  }

  factory DeviceModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawHistory = map['nameHistory'] as List<dynamic>? ?? [];
    final history = rawHistory
        .map((e) => NameHistoryEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return DeviceModel(
      deviceId: id ?? map['deviceId'] as String? ?? 'unknown',
      currentName: map['currentName'] as String? ?? 'Device ${id ?? ""}',
      nameHistory: history,
      status: map['status'] as String? ?? 'idle',
      activeTripId: map['activeTripId'] as String?,
      lastUpdated: parseDate(map['lastUpdated']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'currentName': currentName,
      'nameHistory': nameHistory.map((e) => e.toMap()).toList(),
      'status': status,
      'activeTripId': activeTripId,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : FieldValue.serverTimestamp(),
    };
  }

  DeviceModel copyWith({
    String? deviceId,
    String? currentName,
    List<NameHistoryEntry>? nameHistory,
    String? status,
    String? activeTripId,
    bool clearActiveTrip = false,
    DateTime? lastUpdated,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      currentName: currentName ?? this.currentName,
      nameHistory: nameHistory ?? this.nameHistory,
      status: status ?? this.status,
      activeTripId: clearActiveTrip ? null : (activeTripId ?? this.activeTripId),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
