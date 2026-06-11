import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_service.dart';
import '../../features/driver/home/driver_home_screen.dart' show driverTripsProvider;

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — refresh auth + critical providers
      _onResume();
    }
  }

  Future<void> _onResume() async {
    // 1. Refresh Firebase ID token (avoid expired-token errors)
    await SessionService.refreshAuthToken();

    // 2. Invalidate providers that may have stale data
    //    Drivers list, trip history, active trip — let them refetch on next read
    ref.invalidate(driverTripsProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
