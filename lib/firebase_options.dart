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
    apiKey: 'AIzaSyDdSvm_K4bv51LEY3ncVgOMwDDs_Pr1HK0',
    appId: '1:683792963487:web:447b8aab92ba386a140faa',
    messagingSenderId: '683792963487',
    projectId: 'iv-drip-monitor-49391',
    authDomain: 'iv-drip-monitor-49391.firebaseapp.com',
    storageBucket: 'iv-drip-monitor-49391.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAEhsHMVwABCkmXVGVeboQQ6F8yDz-rCK0',
    appId: '1:683792963487:android:212e2a40cface2b6140faa',
    messagingSenderId: '683792963487',
    projectId: 'iv-drip-monitor-49391',
    storageBucket: 'iv-drip-monitor-49391.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBJf8K22qxUM_2grlAFZif_66bGTsz8wvk',
    appId: '1:683792963487:ios:e0699540a8c70e0d140faa',
    messagingSenderId: '683792963487',
    projectId: 'iv-drip-monitor-49391',
    storageBucket: 'iv-drip-monitor-49391.firebasestorage.app',
    iosBundleId: 'com.hospital.ivdrip.ivDripMonitor',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBJf8K22qxUM_2grlAFZif_66bGTsz8wvk',
    appId: '1:683792963487:ios:e0699540a8c70e0d140faa',
    messagingSenderId: '683792963487',
    projectId: 'iv-drip-monitor-49391',
    storageBucket: 'iv-drip-monitor-49391.firebasestorage.app',
    iosBundleId: 'com.hospital.ivdrip.ivDripMonitor',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDdSvm_K4bv51LEY3ncVgOMwDDs_Pr1HK0',
    appId: '1:683792963487:web:45fa7f0ba683ca53140faa',
    messagingSenderId: '683792963487',
    projectId: 'iv-drip-monitor-49391',
    authDomain: 'iv-drip-monitor-49391.firebaseapp.com',
    storageBucket: 'iv-drip-monitor-49391.firebasestorage.app',
  );
}
