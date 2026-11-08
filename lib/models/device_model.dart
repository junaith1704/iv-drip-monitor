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
  final String status;
  final String? activeTripId;
  final DateTime? lastUpdated;
  final String? speed;
  final int? battery;
  final double? dpm;
  final int? drops;
  final bool boardOnline;
  final String? boardIp;
  final DateTime? lastSeen;

  DeviceModel({
    required this.deviceId,
    required this.currentName,
    this.nameHistory = const [],
    this.status = 'idle',
    this.activeTripId,
    this.lastUpdated,
    this.speed,
    this.battery,
    this.dpm,
    this.drops,
    this.boardOnline = true,
    this.boardIp,
    this.lastSeen,
  });

  bool get isRunning => status == 'running';
  bool get isStuck => status == 'stuck';
  bool get isAlarm => status == 'alarm';
  bool get isIdle => status == 'idle';
  bool get isLowBattery => battery != null && battery! >= 1 && battery! <= 15;

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

    int? parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    double? parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    bool parseBool(dynamic val, bool fallback) {
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      return fallback;
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
      speed: map['speed'] as String?,
      battery: parseInt(map['battery']),
      dpm: parseDouble(map['dpm']),
      drops: parseInt(map['drops']),
      boardOnline: parseBool(map['boardOnline'], true),
      boardIp: map['boardIp'] as String?,
      lastSeen: parseDate(map['lastSeen']),
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
      'speed': speed,
      'battery': battery,
      'dpm': dpm,
      'drops': drops,
      'boardOnline': boardOnline,
      if (boardIp != null) 'boardIp': boardIp,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
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
    String? speed,
    int? battery,
    double? dpm,
    int? drops,
    bool? boardOnline,
    String? boardIp,
    bool clearBoardIp = false,
    DateTime? lastSeen,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      currentName: currentName ?? this.currentName,
      nameHistory: nameHistory ?? this.nameHistory,
      status: status ?? this.status,
      activeTripId: clearActiveTrip ? null : (activeTripId ?? this.activeTripId),
      lastUpdated: lastUpdated ?? this.lastUpdated,
      speed: speed ?? this.speed,
      battery: battery ?? this.battery,
      dpm: dpm ?? this.dpm,
      drops: drops ?? this.drops,
      boardOnline: boardOnline ?? this.boardOnline,
      boardIp: clearBoardIp ? null : (boardIp ?? this.boardIp),
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
