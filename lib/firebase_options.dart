// File generated to provide Firebase options directly to Firebase.initializeApp
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android; // fallback to android options
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCdkcRgaQM4vyvlDoD-aaLYqRc1ZVpcG5o',
    appId: '1:806741376387:android:65c142f16dc482b57d0ab6',
    messagingSenderId: '806741376387',
    projectId: 'projectmilktea',
    storageBucket: 'projectmilktea.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCdkcRgaQM4vyvlDoD-aaLYqRc1ZVpcG5o',
    appId: '1:806741376387:web:65c142f16dc482b57d0ab6',
    messagingSenderId: '806741376387',
    projectId: 'projectmilktea',
    authDomain: 'projectmilktea.firebaseapp.com',
    storageBucket: 'projectmilktea.firebasestorage.app',
  );
}
