import 'package:firebase_messaging/firebase_messaging.dart';

/// V1 surface for the push permission soft primer flow. FCM token capture,
/// primer modal UI, and persistence live in separate modules.
final class PushPermissionService {
  PushPermissionService._();

  static Future<AuthorizationStatus> getCurrentStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  static Future<AuthorizationStatus> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus;
  }
}
