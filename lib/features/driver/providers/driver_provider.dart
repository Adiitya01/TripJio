import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/location_service.dart';
import '../../../data/repositories/location_repository.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../data/repositories/request_repository.dart';
import '../../../data/models/request_model.dart';

// Driver online/offline toggle — shared across all driver screens
final driverOnlineProvider = StateProvider<bool>((ref) => false);

// Trip history filter: 0=All, 1=Completed, 2=Cancelled
final tripFilterProvider = StateProvider<int>((ref) => 0);

// Foreground GPS stream — emits Position every 10m moved
final driverLocationStreamProvider = StreamProvider<Position>((ref) {
  final isOnline = ref.watch(driverOnlineProvider);
  if (!isOnline) return const Stream.empty();
  return LocationService().getLocationStream();
});

// Sync online status to Supabase when driver toggles.
// Server-side blocks going offline while a trip is active — we
// revert the toggle and surface a message.
final driverOnlineStatusSyncProvider = Provider<void>((ref) {
  final isOnline = ref.watch(driverOnlineProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  () async {
    if (isOnline) {
      // ⚛️ ACID: combined go-online + GPS push in ONE transaction.
      // Driver never appears online with stale location.
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        await Supabase.instance.client.rpc('go_online_with_location', params: {
          'p_user_id': uid,
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
        });
      } catch (_) {
        // Fallback: at least mark online (no location)
        try {
          await DriverRepository().setOnlineStatus(uid, online: true);
        } catch (_) {}
      }
    } else {
      // Going offline — safe RPC blocks if active trip
      try {
        final result =
            await DriverRepository().setOnlineStatus(uid, online: false);
        if (result == 'blocked_active_trip') {
          ref.read(driverOnlineProvider.notifier).state = true;
        }
      } catch (_) {}
    }
  }();
});

// On cold start: restore driver's previous online state from Supabase.
// Solves: app killed while online → user must manually toggle online again.
final driverStateRestoreProvider = FutureProvider<void>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    final state = await DriverRepository().getDriverState(uid);
    if (state == null) return;
    final wasOnline = state['is_online'] as bool? ?? false;
    if (wasOnline) {
      ref.read(driverOnlineProvider.notifier).state = true;
    }
  } catch (_) {/* network glitch — driver can toggle manually */}
});

// Listen for incoming load requests when driver is online
final incomingRequestProvider = StreamProvider<RequestModel>((ref) {
  final isOnline = ref.watch(driverOnlineProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (!isOnline || uid == null) return const Stream.empty();
  return RequestRepository().listenForIncomingRequests(uid);
});

// Currently active incoming request (shown to driver)
final activeIncomingRequestProvider = StateProvider<RequestModel?>((ref) => null);

// Periodic heartbeat — keeps parked drivers visible + auto-expires crashed apps.
// Fires every 60s while online. If the app dies, no more heartbeats → driver
// disappears from load owner's map after the 3-min freshness window.
final driverHeartbeatProvider = Provider<void>((ref) {
  final isOnline = ref.watch(driverOnlineProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;

  Timer? timer;
  if (isOnline && uid != null) {
    // Fire immediately + every 60s thereafter
    LocationRepository().heartbeat(uid);
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      LocationRepository().heartbeat(uid);
    });
  }
  ref.onDispose(() => timer?.cancel());
});

// Auto-push driver GPS to Supabase whenever location updates
final driverLocationSyncProvider = Provider<void>((ref) {
  final locationAsync = ref.watch(driverLocationStreamProvider);
  final repo = LocationRepository();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  locationAsync.whenData((position) {
    if (uid == null) return;
    repo.updateDriverLocation(
      driverId: uid,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  });
});
