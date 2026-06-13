// Firebase 설정 파일입니다.
// Firebase 프로젝트나 앱을 다시 만들면 `flutterfire configure`로 재생성하세요.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          '현재 Firebase 로그인은 Android와 Web 설정만 준비되어 있습니다.',
        );
      default:
        throw UnsupportedError('지원하지 않는 플랫폼입니다.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCu4vNGcriF-_bXQnhn2YXWEt9szeccJtg',
    appId: '1:388700129782:web:62c029aeb165a4f0499fd7',
    messagingSenderId: '388700129782',
    projectId: 'dingdong-app-bcc42',
    authDomain: 'dingdong-app-bcc42.firebaseapp.com',
    storageBucket: 'dingdong-app-bcc42.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCu4vNGcriF-_bXQnhn2YXWEt9szeccJtg',
    appId: '1:388700129782:android:e9423c0e1c4e00ae499fd7',
    messagingSenderId: '388700129782',
    projectId: 'dingdong-app-bcc42',
    storageBucket: 'dingdong-app-bcc42.firebasestorage.app',
  );
}
