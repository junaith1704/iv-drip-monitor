import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/service_request_model.dart';
import 'firebase_service.dart';

class ServiceRequestService extends ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // In-memory fallback mock requests
  final List<ServiceRequestModel> _mockRequests = [
    ServiceRequestModel(
      requestId: 'req_001',
      raisedBy: 'nurse_sarah_01',
      raisedByName: 'Nurse Sarah Jenkins, RN',
      deviceId: 'ESP32_03',
      deviceName: 'Floor 2 - Bed 105',
      issueText: 'Optical drip chamber sensor latch loose. Intermittent drop detection failure.',
      status: 'open',
      raisedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    ServiceRequestModel(
      requestId: 'req_002',
      raisedBy: 'nurse_david_02',
      raisedByName: 'Nurse David Chen, BSN',
      deviceId: 'ESP32_01',
      deviceName: 'Floor 2 - Bed 101',
      issueText: 'Battery level draining faster than usual, please replace internal LiPo pack.',
      status: 'resolved',
      raisedAt: DateTime.now().subtract(const Duration(days: 2)),
      resolvedAt: DateTime.now().subtract(const Duration(days: 1)),
      resolvedBy: 'Dr. Robert Vance (Clinical Admin)',
    ),
  ];

  final StreamController<List<ServiceRequestModel>> _requestsStreamController =
      StreamController<List<ServiceRequestModel>>.broadcast();

  ServiceRequestService() {
    _requestsStreamController.add(List.unmodifiable(_mockRequests));
  }

  Stream<List<ServiceRequestModel>> _getMockStream() {
    return _requestsStreamController.stream.asBroadcastStream(
      onListen: (_) {
        _requestsStreamController.add(List.unmodifiable(_mockRequests));
      },
    );
  }

  /// Stream requests for a specific nurse
  Stream<List<ServiceRequestModel>> streamNurseRequests(String nurseUserId) {
    if (FirebaseService.isMockFallback) {
      return _getMockStream().map((list) {
        return list.where((r) => r.raisedBy == nurseUserId).toList();
      });
    }

    try {
      return _firestore
          .collection('serviceRequests')
          .where('raisedBy', isEqualTo: nurseUserId)
          .orderBy('raisedAt', descending: true)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) {
          return _mockRequests.where((r) => r.raisedBy == nurseUserId).toList();
        }
        return snap.docs.map((doc) => ServiceRequestModel.fromFirestore(doc)).toList();
      });
    } catch (e) {
      debugPrint('[ServiceRequestService] streamNurseRequests error: $e');
      return _requestsStreamController.stream.map((list) {
        return list.where((r) => r.raisedBy == nurseUserId).toList();
      });
    }
  }

  /// Stream all OPEN requests for Admin dashboard/resolution
  Stream<List<ServiceRequestModel>> streamOpenRequests() {
    if (FirebaseService.isMockFallback) {
      return _getMockStream().map((list) {
        return list.where((r) => r.isOpen).toList();
      });
    }

    try {
      return _firestore
          .collection('serviceRequests')
          .where('status', isEqualTo: 'open')
          .orderBy('raisedAt', descending: true)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) {
          return _mockRequests.where((r) => r.isOpen).toList();
        }
        return snap.docs.map((doc) => ServiceRequestModel.fromFirestore(doc)).toList();
      });
    } catch (e) {
      debugPrint('[ServiceRequestService] streamOpenRequests error: $e');
      return _getMockStream().map((list) {
        return list.where((r) => r.isOpen).toList();
      });
    }
  }

  /// Stream all requests (both open & resolved) for history review
  Stream<List<ServiceRequestModel>> streamAllRequests() {
    if (FirebaseService.isMockFallback) {
      return _getMockStream();
    }

    try {
      return _firestore
          .collection('serviceRequests')
          .orderBy('raisedAt', descending: true)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return _mockRequests;
        return snap.docs.map((doc) => ServiceRequestModel.fromFirestore(doc)).toList();
      });
    } catch (e) {
      debugPrint('[ServiceRequestService] streamAllRequests error: $e');
      return _requestsStreamController.stream;
    }
  }

  /// Nurse submits a new issue/request
  Future<void> submitRequest({
    required String raisedBy,
    String? raisedByName,
    String? deviceId,
    String? deviceName,
    required String issueText,
  }) async {
    final requestId = 'req_${_uuid.v4().substring(0, 8)}';
    final now = DateTime.now();

    final newReq = ServiceRequestModel(
      requestId: requestId,
      raisedBy: raisedBy,
      raisedByName: raisedByName,
      deviceId: deviceId,
      deviceName: deviceName,
      issueText: issueText.trim(),
      status: 'open',
      raisedAt: now,
    );

    if (FirebaseService.isMockFallback) {
      _mockRequests.insert(0, newReq);
      _requestsStreamController.add(List.unmodifiable(_mockRequests));
      notifyListeners();
      return;
    }

    try {
      await _firestore.collection('serviceRequests').doc(requestId).set(newReq.toMap());
    } catch (e) {
      debugPrint('[ServiceRequestService] submitRequest error: $e');
      _mockRequests.insert(0, newReq);
      _requestsStreamController.add(List.unmodifiable(_mockRequests));
    }
    notifyListeners();
  }

  /// Admin resolves request. Per specs:
  /// - Admin marks resolved, which makes it disappear from the open requests queue
  /// - Admin CANNOT edit or delete the nurse's issue text
  Future<void> resolveRequest({
    required String requestId,
    required String resolvedBy,
  }) async {
    final now = DateTime.now();

    if (FirebaseService.isMockFallback) {
      final index = _mockRequests.indexWhere((r) => r.requestId == requestId);
      if (index != -1) {
        _mockRequests[index] = _mockRequests[index].copyWith(
          status: 'resolved',
          resolvedAt: now,
          resolvedBy: resolvedBy,
        );
        _requestsStreamController.add(List.unmodifiable(_mockRequests));
      }
      notifyListeners();
      return;
    }

    try {
      await _firestore.collection('serviceRequests').doc(requestId).update({
        'status': 'resolved',
        'resolvedAt': Timestamp.fromDate(now),
        'resolvedBy': resolvedBy,
      });
    } catch (e) {
      debugPrint('[ServiceRequestService] resolveRequest error: $e');
      final index = _mockRequests.indexWhere((r) => r.requestId == requestId);
      if (index != -1) {
        _mockRequests[index] = _mockRequests[index].copyWith(
          status: 'resolved',
          resolvedAt: now,
          resolvedBy: resolvedBy,
        );
        _requestsStreamController.add(List.unmodifiable(_mockRequests));
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _requestsStreamController.close();
    super.dispose();
  }
}
