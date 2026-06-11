import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static const _channelId = 'tripjio_main';
  static const _channelName = 'TripJio Notifications';

  // ─── Initialize ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      // 1. Request FCM permission (may be blocked in incognito/some browsers)
      final settings = await _fcm.requestPermission(
          alert: true, badge: true, sound: true);

      // 2. Save FCM token only if permission granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _fcm.getToken();
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', token);
        }
      }
    } catch (_) {
      // Notifications blocked or unavailable (incognito, unsupported browser)
      // App continues working — notifications are non-critical
    }

    // 3. Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (_) {},
    );

    // 4. Create Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 5. Handle FCM foreground messages as local notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showNotification(
          title: notification.title ?? 'TripJio',
          body: notification.body ?? '',
        );
      }
    });
  }

  // ─── Show local notification ───────────────────────────────────────────────

  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
          android: androidDetails, iOS: iosDetails),
    );
  }

  // ─── Typed notification helpers ────────────────────────────────────────────

  /// Driver receives a new load request
  Future<void> notifyNewLoadRequest({
    required String loadOwnerName,
    required String pickup,
    required String drop,
  }) =>
      showNotification(
        id: 1001,
        title: '🚛 New Load Request!',
        body: '$loadOwnerName · $pickup → $drop',
      );

  /// Load owner's request was accepted by driver
  Future<void> notifyRequestAccepted({
    required String driverName,
    required String vehicleNumber,
  }) =>
      showNotification(
        id: 1002,
        title: '✅ Request Accepted!',
        body: '$driverName ($vehicleNumber) is on the way',
      );

  /// Driver has arrived at pickup
  Future<void> notifyDriverArrived({required String driverName}) =>
      showNotification(
        id: 1003,
        title: '📍 Driver Arrived!',
        body: '$driverName has reached your pickup location',
      );

  /// Trip completed
  Future<void> notifyTripCompleted({required String distance}) =>
      showNotification(
        id: 1004,
        title: '🎉 Trip Completed!',
        body: 'Trip of $distance km completed successfully',
      );
}
