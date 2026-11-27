// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// [FirebaseOptions] loaded at runtime from the `.env` asset file.
///
/// The `.env` file is registered in `pubspec.yaml` under `flutter.assets` and
/// is loaded by [main.dart] before [Firebase.initializeApp] is called.  It is
/// listed in `.gitignore` so API keys are never committed to source control.
///
/// For CI/CD pipelines, inject the `.env` contents as a secret file or use
/// `--dart-define` flags — do NOT add the real `.env` to the repository.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Reads a required key from the loaded `.env` map.
  /// Throws a clear error at startup if the key is missing so misconfiguration
  /// is caught immediately instead of at Firebase init time.
  static String _env(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing Firebase config key "$key". '
        'Ensure .env exists with all required values '
        '(see .env.example for the full list).',
      );
    }
    return value;
  }

  // ── Platform options ─────────────────────────────────────────────────────

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _env('FIREBASE_ANDROID_API_KEY'),
        appId: _env('FIREBASE_ANDROID_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _env('FIREBASE_IOS_API_KEY'),
        appId: _env('FIREBASE_IOS_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
        iosBundleId: _env('FIREBASE_IOS_BUNDLE_ID'),
      );

  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: _env('FIREBASE_IOS_API_KEY'),
        appId: _env('FIREBASE_IOS_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
        iosBundleId: _env('FIREBASE_IOS_BUNDLE_ID'),
      );

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _env('FIREBASE_WEB_API_KEY'),
        appId: _env('FIREBASE_WEB_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        authDomain: _env('FIREBASE_AUTH_DOMAIN'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
        measurementId: _env('FIREBASE_WEB_MEASUREMENT_ID'),
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: _env('FIREBASE_WEB_API_KEY'),
        appId: _env('FIREBASE_WINDOWS_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        authDomain: _env('FIREBASE_AUTH_DOMAIN'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
        measurementId: _env('FIREBASE_WINDOWS_MEASUREMENT_ID'),
      );
}
