import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
    );
    _initialized = true;
  }

  static Future<void> showNoiseAlert({
    required double db,
    required int durationMin,
    required double limit,
  }) async {
    await _plugin.show(
      1,
      '🔊 Noise Alert!',
      'Noise ${db.toStringAsFixed(0)} dB exceeded ${limit.toStringAsFixed(0)} dB for $durationMin min.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'noise_alert',
          'Noise Alerts',
          channelDescription: 'Alerts when noise exceeds your limit',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> showInstantAlert({required double db}) async {
    await _plugin.show(
      2,
      '🚨 HIGH NOISE DETECTED!',
      'Current level: ${db.toStringAsFixed(0)} dB. It is too loud here!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_alert',
          'Instant Noise Alerts',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }
}
