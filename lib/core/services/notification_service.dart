import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart' show navigatorKey;
import '../../features/driver/home/driver_home_screen.dart';
import '../../features/load_owner/home/load_owner_home_screen.dart';

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

      // 2. Save FCM token if permission granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _fcm.getToken();
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', token);
          await syncFcmTokenToSupabase(token);
        }
      }

      // 3. Listen for token refresh (FCM rotates tokens periodically)
      _fcm.onTokenRefresh.listen((token) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        await syncFcmTokenToSupabase(token);
      });
    } catch (_) {
      // Notifications blocked or unavailable
    }

    // 3. Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        // Payload was JSON-encoded from the FCM data map when we surfaced
        // this notification via _showLocalNotification.
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          _handleNotificationTap(const {});
          return;
        }
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            _handleNotificationTap(decoded.cast<String, dynamic>());
          }
        } catch (_) {/* ignore malformed payload */}
      },
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
          payload: jsonEncode(message.data),
        );
      }
    });

    // 6. Route notification taps.
    // Terminated-app open:
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      // Delay one frame so the navigator has mounted before we push.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _handleNotificationTap(initialMessage.data));
    }
    // Background-app open:
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });
  }

  // ─── Tap routing ──────────────────────────────────────────────────────────

  /// Routes a notification tap based on its FCM `data` payload. We push the
  /// user to the appropriate home screen and let its Realtime listeners
  /// surface the actual incoming-request / live-tracking screen — this keeps
  /// the routing dependency-light and avoids reconstructing full models from
  /// the payload.
  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final type = data['type']?.toString();
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getString('userType');
    Widget? target;
    if (type == 'incoming_request') {
      target = const DriverHomeScreen();
    } else if (type == 'trip_accepted') {
      target = const LoadOwnerHomeScreen();
    } else if (type == 'trip_completed' || type == 'trip_cancelled') {
      target = userType == 'driver'
          ? const DriverHomeScreen()
          : const LoadOwnerHomeScreen();
    }
    if (target == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target!),
      (_) => false,
    );
  }

  // ─── Sync FCM token to Supabase active_sessions ──────────────────────────

  /// Saves the device's FCM token to the user's active_sessions row.
  /// The Edge Function reads this to know where to send push notifications.
  Future<void> syncFcmTokenToSupabase(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await Supabase.instance.client
          .from('active_sessions')
          .update({'fcm_token': token})
          .eq('user_id', uid);
    } catch (_) {/* network glitch — will retry on next token refresh */}
  }

  // ─── Show local notification ───────────────────────────────────────────────

  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    String? payload,
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
      payload: payload,
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
