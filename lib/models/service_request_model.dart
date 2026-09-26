import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String requestId;
  final String raisedBy;
  final String? raisedByName;
  final String? deviceId;
  final String? deviceName;
  final String issueText;
  final String status; // 'open' | 'resolved'
  final DateTime raisedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  ServiceRequestModel({
    required this.requestId,
    required this.raisedBy,
    this.raisedByName,
    this.deviceId,
    this.deviceName,
    required this.issueText,
    this.status = 'open',
    required this.raisedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved';

  factory ServiceRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceRequestModel.fromMap(data, doc.id);
  }

  factory ServiceRequestModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ServiceRequestModel(
      requestId: id ?? map['requestId'] as String? ?? '',
      raisedBy: map['raisedBy'] as String? ?? '',
      raisedByName: map['raisedByName'] as String?,
      deviceId: map['deviceId'] as String?,
      deviceName: map['deviceName'] as String?,
      issueText: map['issueText'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      raisedAt: parseDate(map['raisedAt']),
      resolvedAt: map['resolvedAt'] != null ? parseDate(map['resolvedAt']) : null,
      resolvedBy: map['resolvedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'raisedBy': raisedBy,
      if (raisedByName != null) 'raisedByName': raisedByName,
      if (deviceId != null) 'deviceId': deviceId,
      if (deviceName != null) 'deviceName': deviceName,
      'issueText': issueText,
      'status': status,
      'raisedAt': Timestamp.fromDate(raisedAt),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
    };
  }

  ServiceRequestModel copyWith({
    String? requestId,
    String? raisedBy,
    String? raisedByName,
    String? deviceId,
    String? deviceName,
    String? issueText,
    String? status,
    DateTime? raisedAt,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return ServiceRequestModel(
      requestId: requestId ?? this.requestId,
      raisedBy: raisedBy ?? this.raisedBy,
      raisedByName: raisedByName ?? this.raisedByName,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      issueText: issueText ?? this.issueText,
      status: status ?? this.status,
      raisedAt: raisedAt ?? this.raisedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }
}
