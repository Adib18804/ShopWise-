import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps [FlutterLocalNotificationsPlugin] for ShopWise smart alerts.
///
/// Call [init] once in [main] before [runApp]. Then call
/// [showExpiryWarning] / [showStockOutWarning] from the dashboard after the
/// Smart Assistant summary loads.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    if (_initialised) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Request Android 13+ notification permission (no-op on older versions).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialised = true;
  }

  // ---------------------------------------------------------------------------
  // Alert helpers
  // ---------------------------------------------------------------------------

  /// Shows a Bangla expiry warning: "সতর্কতা: N টি পণ্যের মেয়াদ শেষ হচ্ছে!"
  Future<void> showExpiryWarning(int count) async {
    if (!_initialised || count <= 0) return;
    await _show(
      id: 1,
      title: 'সতর্কতা: মেয়াদ শেষের ঝুঁকি ⚠️',
      body: '$count টি পণ্যের মেয়াদ শেষ হচ্ছে! এখনই পদক্ষেপ নিন।',
    );
  }

  /// Shows a Bangla stock-out warning: "সতর্কতা: N টি পণ্যের স্টক শেষ হচ্ছে!"
  Future<void> showStockOutWarning(int count) async {
    if (!_initialised || count <= 0) return;
    await _show(
      id: 2,
      title: 'সতর্কতা: স্টক শেষ হওয়ার ঝুঁকি 📦',
      body: '$count টি পণ্যের স্টক শেষ হতে পারে। রিস্টক করুন।',
    );
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'shopwise_alerts',   // channel id
    'ShopWise সতর্কতা',  // channel name
    channelDescription: 'স্টক ও মেয়াদ সংক্রান্ত সতর্কতা',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    playSound: true,
  );

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(android: _androidDetails);
    await _plugin.show(id, title, body, details);
  }
}
