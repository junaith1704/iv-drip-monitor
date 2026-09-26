// File generated for iv-drip-monitor Firebase configuration
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_placeholder_iv_drip_monitor_web_key',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'iv-drip-monitor',
    authDomain: 'iv-drip-monitor.firebaseapp.com',
    storageBucket: 'iv-drip-monitor.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_placeholder_iv_drip_monitor_android_key',
    appId: '1:123456789012:android:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'iv-drip-monitor',
    storageBucket: 'iv-drip-monitor.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_placeholder_iv_drip_monitor_ios_key',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'iv-drip-monitor',
    storageBucket: 'iv-drip-monitor.appspot.com',
    iosBundleId: 'com.hospital.ivdrip.ivDripMonitor',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA_placeholder_iv_drip_monitor_macos_key',
    appId: '1:123456789012:ios:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'iv-drip-monitor',
    storageBucket: 'iv-drip-monitor.appspot.com',
    iosBundleId: 'com.hospital.ivdrip.ivDripMonitor',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA_placeholder_iv_drip_monitor_win_key',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'iv-drip-monitor',
    authDomain: 'iv-drip-monitor.firebaseapp.com',
    storageBucket: 'iv-drip-monitor.appspot.com',
  );
}
