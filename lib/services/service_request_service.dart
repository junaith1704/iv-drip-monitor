import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/service_request_model.dart';
import 'firebase_service.dart';

class ServiceRequestService extends ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final _uuid = const Uuid();

  final List<ServiceRequestModel> _mockRequests = [];

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

  Stream<List<ServiceRequestModel>> streamNurseRequests(String nurseUserId) {
    if (FirebaseService.isMockFallback) {
      return _getMockStream().map((list) {
        return list.where((r) => r.raisedBy == nurseUserId).toList();
      });
    }

    return _firestore
        .collection('serviceRequests')
        .where('raisedBy', isEqualTo: nurseUserId)
        .orderBy('raisedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => ServiceRequestModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<ServiceRequestModel>> streamOpenRequests() {
    if (FirebaseService.isMockFallback) {
      return _getMockStream().map((list) {
        return list.where((r) => r.isOpen).toList();
      });
    }

    return _firestore
        .collection('serviceRequests')
        .where('status', isEqualTo: 'open')
        .orderBy('raisedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => ServiceRequestModel.fromFirestore(doc)).toList();
    });
  }

  Stream<List<ServiceRequestModel>> streamAllRequests() {
    if (FirebaseService.isMockFallback) {
      return _getMockStream();
    }

    return _firestore
        .collection('serviceRequests')
        .orderBy('raisedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => ServiceRequestModel.fromFirestore(doc)).toList();
    });
  }

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

    await _firestore.collection('serviceRequests').doc(requestId).set(newReq.toMap());
    notifyListeners();
  }

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

    await _firestore.collection('serviceRequests').doc(requestId).update({
      'status': 'resolved',
      'resolvedAt': Timestamp.fromDate(now),
      'resolvedBy': resolvedBy,
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _requestsStreamController.close();
    super.dispose();
  }
}
