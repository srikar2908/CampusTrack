import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: "AIzaSyDEMO-API-KEY-1234567890",
        authDomain: "demo-web.firebaseapp.com",
        projectId: "demo-project-id",
        storageBucket: "demo-project-id.appspot.com",
        messagingSenderId: "123456789012",
        appId: "1:123456789012:web:demoappid123456",
        measurementId: "G-DEMOID1234",
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: "AIzaSyDEMO-ANDROID-KEY-0987654321",
          appId: "1:123456789012:android:demoappid098765",
          messagingSenderId: "123456789012",
          projectId: "demo-project-id",
          storageBucket: "demo-project-id.appspot.com",
        );

      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
