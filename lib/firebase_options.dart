import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: "AIzaSyCKFH6B1d_M4BOaG39J-HkKFoewVzC2E1s",
        authDomain: "campustracksahe.firebaseapp.com",
        projectId: "campustracksahe",
        storageBucket: "campustracksahe.firebasestorage.app",
        messagingSenderId: "179056380448",
        appId: "1:179056380448:web:03bd587f3c07dd8fb9ca45",
        measurementId: "G-Z7SJPP0HHQ",
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: "AIzaSyCn8LIlSI4jpoC4QQkY8t4kVqP-xSQx09c",
          appId: "1:179056380448:android:beff382c6e05e939b9ca45",
          messagingSenderId: "179056380448",
          projectId: "campustracksahe",
          storageBucket: "campustracksahe.firebasestorage.app",
        );

      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
