import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class FirebaseService {
  static bool _initialized = false;
  static bool _useMockFallback = false;

  static bool get isInitialized => _initialized;
  static bool get isMockFallback => _useMockFallback;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      _useMockFallback = false;
      debugPrint('[FirebaseService] Successfully initialized Firebase');
    } catch (e) {
      debugPrint('[FirebaseService] Firebase initializeApp encountered: $e');
      debugPrint('[FirebaseService] Engaging clinical mock/offline database layer');
      _initialized = true;
      _useMockFallback = true;
    }
  }

  /// Explicitly force mock or real for testing
  static void setMockFallback(bool value) {
    _useMockFallback = value;
  }
}
