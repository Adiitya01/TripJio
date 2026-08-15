import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_service.dart';
import '../../data/repositories/driver_repository.dart';
import '../../features/driver/home/driver_home_screen.dart' show driverTripsProvider;
import '../../features/driver/providers/driver_provider.dart';

/// Observes app lifecycle events and:
///  - refreshes Firebase auth token on resume
///  - invalidates Riverpod providers so stale data is re-fetched
///  - handles Realtime reconnect (Supabase auto-reconnects but
///    we still need to refetch any provider that subscribes mid-stream)
class AppLifecycleService extends ConsumerStatefulWidget {
  final Widget child;
  const AppLifecycleService({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleService> createState() =>
      _AppLifecycleServiceState();
}

class _AppLifecycleServiceState extends ConsumerState<AppLifecycleService>
    with WidgetsBindingObserver {
  Timer? _idleOfflineTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _idleOfflineTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _idleOfflineTimer?.cancel();
        _onResume();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App backgrounded — start countdown to auto-offline (Uber-style).
        // If still backgrounded after 5 min, voluntarily set offline.
        _scheduleAutoOffline();
        break;
      default:
        break;
    }
  }

  Future<void> _onResume() async {
    await SessionService.refreshAuthToken();
    ref.invalidate(driverTripsProvider);
  }

  void _scheduleAutoOffline() {
    _idleOfflineTimer?.cancel();
    // Only relevant if user is a driver who's currently online
    final isOnline = ref.read(driverOnlineProvider);
    if (!isOnline) return;

    _idleOfflineTimer = Timer(const Duration(minutes: 5), () async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      try {
        await DriverRepository().setOnlineStatus(uid, online: false);
        ref.read(driverOnlineProvider.notifier).state = false;
      } catch (_) {/* server's auto-offline RPC will catch it anyway */}
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
