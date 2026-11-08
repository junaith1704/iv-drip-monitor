import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

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

  AuthService() {
    _initAuthListener();
  }

  void _initAuthListener() {
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
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String uid, String email) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthService] _loadUserProfile error: $e');
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<String?> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user != null) {
        await _loadUserProfile(cred.user!.uid, cred.user!.email ?? email);
        if (_currentUser == null) {
          await _auth.signOut();
          _isLoading = false;
          notifyListeners();
          return 'Account profile not found. Contact the admin.';
        }
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message ?? 'Authentication failed (${e.code})';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Authentication failed: $e';
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    }
    _currentUser = null;
    notifyListeners();
  }

      Future<bool> checkFirstTimeSetup(String email) async {
    try {
      final doc = await _firestore
          .collection('pendingUsers')
          .doc(email.trim().toLowerCase())
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('[AuthService] checkFirstTimeSetup error: $e');
      return false;
    }
  }

  Future<String?> addPendingNurse({required String name, required String email}) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final existing = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return 'This email already has an account';
      await _firestore.collection('pendingUsers').doc(cleanEmail).set({
        'name': name.trim(),
        'email': cleanEmail,
        'role': 'nurse',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Could not add nurse: $e';
    }
  }

  Future<String?> completeFirstTimeSetup(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final cleanEmail = email.trim().toLowerCase();
      final pendingRef = _firestore.collection('pendingUsers').doc(cleanEmail);
      final pendingDoc = await pendingRef.get();

      if (!pendingDoc.exists) {
        _isLoading = false;
        notifyListeners();
        return 'No pending account found for this email';
      }

      final data = pendingDoc.data() ?? {};

      final cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final uid = cred.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'userId': uid,
        'name': data['name'] ?? 'Healthcare Staff',
        'email': cleanEmail,
        'role': data['role'] ?? 'nurse',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await pendingRef.delete();
      await _loadUserProfile(uid, cleanEmail);

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.message ?? 'Account setup failed (${e.code})';
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Account setup failed: $e';
    }
  }


  Future<List<UserModel>> getAllUsers() async {
    try {
      final snap = await _firestore.collection('users').get();
      return snap.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }
}
