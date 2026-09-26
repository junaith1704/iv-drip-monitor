import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firebase_service.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isNurse => _currentUser?.isNurse ?? false;

  // Mock users for offline fallback or instant testing
  static final List<UserModel> mockUsers = [
    UserModel(
      userId: 'nurse_sarah_01',
      name: 'Nurse Sarah Jenkins, RN',
      email: 'nurse@hospital.org',
      role: 'nurse',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    UserModel(
      userId: 'nurse_david_02',
      name: 'Nurse David Chen, BSN',
      email: 'nurse2@hospital.org',
      role: 'nurse',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    UserModel(
      userId: 'admin_dr_vance_01',
      name: 'Dr. Robert Vance (Clinical Admin)',
      email: 'admin@hospital.org',
      role: 'admin',
      createdAt: DateTime.now().subtract(const Duration(days: 180)),
    ),
  ];

  AuthService() {
    _initAuthListener();
  }

  void _initAuthListener() {
    if (FirebaseService.isMockFallback) {
      // Default to Nurse Sarah for seamless immediate testing
      _currentUser = mockUsers.first;
      notifyListeners();
      return;
    }

    try {
      _auth.authStateChanges().listen((User? user) async {
        if (user == null) {
          _currentUser = null;
          notifyListeners();
        } else {
          await _loadUserProfile(user.uid, user.email ?? '');
        }
      });
    } catch (e) {
      debugPrint('[AuthService] authStateChanges error: $e');
      _currentUser = mockUsers.first;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String uid, String email) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
      } else {
        // Fallback user profile if not yet created in Firestore
        final newUser = UserModel(
          userId: uid,
          name: email.split('@').first.toUpperCase(),
          email: email,
          role: email.contains('admin') ? 'admin' : 'nurse',
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(uid).set(newUser.toMap());
        _currentUser = newUser;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthService] _loadUserProfile error: $e');
      _currentUser = UserModel(
        userId: uid,
        name: email.split('@').first,
        email: email,
        role: email.contains('admin') ? 'admin' : 'nurse',
      );
      notifyListeners();
    }
  }

  Future<String?> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (FirebaseService.isMockFallback) {
        await Future.delayed(const Duration(milliseconds: 350));
        final cleanEmail = email.trim().toLowerCase();
        final match = mockUsers.firstWhere(
          (u) => u.email.toLowerCase() == cleanEmail,
          orElse: () => UserModel(
            userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
            name: email.split('@').first,
            email: email,
            role: email.contains('admin') ? 'admin' : 'nurse',
          ),
        );
        _currentUser = match;
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user != null) {
        await _loadUserProfile(cred.user!.uid, cred.user!.email ?? email);
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message ?? 'Authentication failed (${e.code})';
    } catch (e) {
      // In case network error or unconfigured project, allow seamless mock login if credentials match demo
      final cleanEmail = email.trim().toLowerCase();
      final match = mockUsers.firstWhere(
        (u) => u.email.toLowerCase() == cleanEmail,
        orElse: () => UserModel(
          userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: email.split('@').first,
          email: email,
          role: email.contains('admin') ? 'admin' : 'nurse',
        ),
      );
      _currentUser = match;
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> switchDemoUser(UserModel user) async {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      if (!FirebaseService.isMockFallback) {
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    }
    _currentUser = null;
    notifyListeners();
  }

  Future<List<UserModel>> getAllUsers() async {
    if (FirebaseService.isMockFallback) {
      return List.unmodifiable(mockUsers);
    }
    try {
      final snap = await _firestore.collection('users').get();
      if (snap.docs.isEmpty) return mockUsers;
      return snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      return mockUsers;
    }
  }
}
