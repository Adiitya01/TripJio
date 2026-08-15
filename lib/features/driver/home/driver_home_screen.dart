import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/driver_provider.dart';
import 'driver_map_screen.dart';
import 'incoming_load_screen.dart';
import '../profile/driver_settings_screen.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/welcome_dialog.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/models/trip_model.dart';
import 'trip_in_progress_screen.dart';

// Provider — fetches the current driver's trips from Supabase
final driverTripsProvider = FutureProvider<List<TripModel>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];
  return TripRepository().getDriverTrips(uid);
});

// Activates GPS → Supabase sync reliably using ref.listen in initState
class _LocationSyncActivator extends ConsumerStatefulWidget {
  const _LocationSyncActivator();
  @override
  ConsumerState<_LocationSyncActivator> createState() =>
      _LocationSyncActivatorState();
}

class _LocationSyncActivatorState
    extends ConsumerState<_LocationSyncActivator> {
  @override
  void initState() {
    super.initState();
    // Listen to GPS stream and push to Supabase for every position update
    ref.listenManual(driverLocationStreamProvider, (_, next) {
      next.whenData((_) {
        // driverLocationSyncProvider handles the actual Supabase write
        ref.read(driverLocationSyncProvider);
      });
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

const _navy = Color(0xFF003F7D);
const _amber = Color(0xFFF59E0B);

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _lastShownRequestId;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// On app start — if the driver had an active trip going, jump straight to it.
  Future<void> _resumeActiveTrip() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final trip = await TripRepository().getActiveTripForUser(uid);
      if (trip == null || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TripInProgressScreen(trip: trip),
        ),
      );
    } catch (_) {/* network glitch — let user navigate manually */}
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 5.2 — Resume active trip if user closed the app mid-trip
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumeActiveTrip());
    // First-time welcome (shows once, persisted in SharedPreferences)
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => WelcomeDialog.showOnce(context, isDriver: true));
    // Restore previous "online" state from DB
    Future.microtask(() => ref.read(driverStateRestoreProvider));

    // Show feedback if user tries to go offline while in active trip
    ref.listenManual(driverOnlineProvider, (prev, next) {
      if (prev == true && next == false) {
        // The sync provider will revert it if server blocks; we don't
        // know yet, so let the revert fire and surface a snackbar then.
      }
    });

    // Listen for incoming requests and auto-show IncomingLoadScreen
    ref.listenManual(incomingRequestProvider, (_, next) {
      next.whenData((request) async {
        // Stream re-emits the same request on every event — de-dupe so we
        // don't stack multiple IncomingLoadScreen instances.
        if (request.id == _lastShownRequestId) return;
        _lastShownRequestId = request.id;
        final loadOwnerName = await UserRepository()
            .getUser(request.loadOwnerId)
            .then((u) => u?.name ?? 'Load Owner');
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => IncomingLoadScreen(
            request: request,
            loadOwnerName: loadOwnerName,
          ),
        ));
        // Reset once the screen closes (accept/reject/expire) so a genuinely
        // new request from the same driver session can still surface.
        _lastShownRequestId = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(driverOnlineProvider);
    ref.watch(driverOnlineStatusSyncProvider); // sync online status to Supabase
    ref.watch(driverHeartbeatProvider); // keep parked driver visible

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.account_circle_outlined,
              color: Colors.black87, size: 28),
          tooltip: 'Profile',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverSettingsScreen()),
          ),
        ),
        title: Text(
          'TripJio',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!isOnline)
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
              onPressed: () {},
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _navy,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _navy,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [
            Tab(text: 'Find Loads'),
            Tab(text: 'My Trips'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: const [
              _FindLoadsTab(),
              _MyTripsTab(),
            ],
          ),
          // Invisible widget that activates GPS → Supabase sync while online
          const _LocationSyncActivator(),
        ],
      ),
    );
  }
}

// No props needed — reads driverOnlineProvider directly
class _FindLoadsTab extends ConsumerWidget {
  const _FindLoadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(driverOnlineProvider);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _OnlineToggleBanner(),
                if (isOnline) ...[
                  const SizedBox(height: 16),
                  const _StatsRow(),
                  const SizedBox(height: 20),
                  const _NearbyLoadsSection(),
                ] else ...[
                  const SizedBox(height: 64),
                  const _OfflineEmptyState(),
                ],
              ],
            ),
          ),
        ),
        const _BottomActions(),
      ],
    );
  }
}

class _OnlineToggleBanner extends ConsumerWidget {
  const _OnlineToggleBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(driverOnlineProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFF1A7A4A) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Pulsing dot when online (Uber-style)
          isOnline
              ? const _PulsingDot()
              : Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey,
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "You're Online" : "You're Offline",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isOnline ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? 'Receiving load requests'
                      : 'Go online to find loads',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isOnline ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            onChanged: (val) =>
                ref.read(driverOnlineProvider.notifier).state = val,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF2ECC71),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

class _OfflineEmptyState extends StatelessWidget {
  const _OfflineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.black38,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Go online to start',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Turn on availability to see\nnearby load opportunities',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _StatCard(label: 'Trips', value: '0'),
        SizedBox(width: 10),
        _StatCard(label: 'Hours', value: '0'),
        SizedBox(width: 10),
        _StatCard(label: 'Requests', value: '0'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyLoadsSection extends StatelessWidget {
  const _NearbyLoadsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nearby Loads',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'See All',
                style: GoogleFonts.poppins(
                  color: _navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Real requests are pushed via Supabase Realtime — IncomingLoadScreen auto-opens
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined,
                  size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                'No new loads yet',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "We'll notify you when a load owner sends a request",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadCard extends StatefulWidget {
  final String company;
  final String location;
  final String vehicleType;
  final String tripDistance;
  final bool isNew;

  const _LoadCard({
    required this.company,
    required this.location,
    required this.vehicleType,
    required this.tripDistance,
    required this.isNew,
  });

  @override
  State<_LoadCard> createState() => _LoadCardState();
}

class _LoadCardState extends State<_LoadCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: widget.isNew ? _amber : Colors.grey.shade200,
          width: widget.isNew ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.company,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              if (widget.isNew)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Colors.black45),
              const SizedBox(width: 4),
              Text(
                widget.location,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.vehicleType,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                widget.tripDistance,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Animated truck route
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final t = _ctrl.value;
                  return SizedBox(
                    height: 22,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Track line
                        Positioned(
                          left: 4,
                          right: 4,
                          top: 10,
                          child: Container(
                              height: 1.5, color: Colors.grey.shade200),
                        ),
                        // Amber progress line
                        Positioned(
                          left: 4,
                          top: 10,
                          child: Container(
                            height: 1.5,
                            width: (t * (trackWidth - 8)).clamp(0.0, trackWidth - 8),
                            color: _amber.withValues(alpha: 0.5),
                          ),
                        ),
                        // Origin dot
                        Positioned(
                          left: 0,
                          top: 7,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _navy,
                            ),
                          ),
                        ),
                        // Animated truck
                        Positioned(
                          left: (t * (trackWidth - 20)).clamp(0.0, trackWidth - 20),
                          top: 1,
                          child: const Icon(
                            Icons.local_shipping,
                            size: 20,
                            color: _amber,
                          ),
                        ),
                        // Destination dot
                        Positioned(
                          right: 0,
                          top: 7,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// No props — reads/writes driverOnlineProvider directly, navigates internally
class _BottomActions extends ConsumerWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(driverOnlineProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: isOnline
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverMapScreen()),
                    ),
                    icon: const Icon(Icons.map_outlined, color: Colors.black87, size: 20),
                    label: Text(
                      'Map',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                    label: Text(
                      'Refresh',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () =>
                    ref.read(driverOnlineProvider.notifier).state = true,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Go Online',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    );
  }
}

// ─── My Trips Tab ────────────────────────────────────────────────────────────

// Loads real trips from Supabase
class _MyTripsTab extends ConsumerWidget {
  const _MyTripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(tripFilterProvider);
    final tripsAsync = ref.watch(driverTripsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              _FilterChipBtn(
                label: 'All',
                selected: filter == 0,
                onTap: () => ref.read(tripFilterProvider.notifier).state = 0,
              ),
              const SizedBox(width: 8),
              _FilterChipBtn(
                label: 'Completed',
                selected: filter == 1,
                onTap: () => ref.read(tripFilterProvider.notifier).state = 1,
              ),
              const SizedBox(width: 8),
              _FilterChipBtn(
                label: 'Cancelled',
                selected: filter == 2,
                onTap: () => ref.read(tripFilterProvider.notifier).state = 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: tripsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: _navy)),
            error: (e, _) => Center(
              child: Text('Failed to load trips',
                  style: TextStyle(color: Colors.red.shade700)),
            ),
            data: (trips) {
              final filtered = filter == 1
                  ? trips.where((t) => t.status == 'completed').toList()
                  : filter == 2
                      ? trips.where((t) => t.status == 'cancelled').toList()
                      : trips;

              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: filter == 0
                      ? 'No trips yet'
                      : filter == 1
                          ? 'No completed trips'
                          : 'No cancelled trips',
                  message: filter == 0
                      ? 'Your accepted loads will appear here.\nGo online to start receiving requests!'
                      : 'Trips with this status will appear here.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.refresh(driverTripsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _TripHistoryCard(trip: _toRecord(filtered[i])),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  _TripRecord _toRecord(TripModel t) {
    final isCompleted = t.status == 'completed';
    final time = DateFormat('MMM d, hh:mm a').format(t.createdAt.toLocal());
    return _TripRecord(
      status: t.status.toUpperCase(),
      from: t.pickupAddress,
      to: t.dropAddress,
      customer:
          t.weightKg != null ? '${t.weightKg!.round()}kg' : 'No weight',
      distance: t.distanceKm != null
          ? '${t.distanceKm!.toStringAsFixed(1)} km'
          : '-',
      time: time,
      isCompleted: isCompleted,
    );
  }
}

class _TripRecord {
  final String status;
  final String from;
  final String to;
  final String customer;
  final String distance;
  final String time;
  final bool isCompleted;

  const _TripRecord({
    required this.status,
    required this.from,
    required this.to,
    required this.customer,
    required this.distance,
    required this.time,
    required this.isCompleted,
  });
}

class _FilterChipBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _navy : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  final _TripRecord trip;

  const _TripHistoryCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final statusColor = trip.isCompleted ? const Color(0xFF1A7A4A) : Colors.red;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    trip.status,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                trip.time,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _navy,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${trip.from}  →  ${trip.to}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(trip.customer,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                  )),
              Text(trip.distance,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing online indicator (Uber/Rapido-style) ──────────────────────────
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: 18 * (0.5 + _ctrl.value * 0.5),
                height: 18 * (0.5 + _ctrl.value * 0.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
                      .withValues(alpha: 1.0 - _ctrl.value),
                ),
              ),
              // Inner solid dot
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
