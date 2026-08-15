import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'trip_detail_screen.dart';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);

class _HistoryPayload {
  final List<TripHistoryItem> items;
  final bool viewerIsDriver;
  const _HistoryPayload({required this.items, required this.viewerIsDriver});
}

final _tripHistoryProvider = FutureProvider<_HistoryPayload>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return const _HistoryPayload(items: [], viewerIsDriver: false);
  }
  final user = await UserRepository().getUser(uid);
  if (user == null) {
    return const _HistoryPayload(items: [], viewerIsDriver: false);
  }
  final isDriver = user.userType == 'driver';
  final items = await TripRepository()
      .getTripHistory(userId: uid, isDriver: isDriver, limit: 50);
  return _HistoryPayload(items: items, viewerIsDriver: isDriver);
});

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(_tripHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Trip history',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: tripsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _navy)),
        error: (_, __) => const _ErrorState(),
        data: (payload) {
          if (payload.items.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: _navy,
            onRefresh: () async => ref.refresh(_tripHistoryProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: payload.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TripCard(
                item: payload.items[i],
                viewerIsDriver: payload.viewerIsDriver,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripHistoryItem item;
  final bool viewerIsDriver;
  const _TripCard({required this.item, required this.viewerIsDriver});

  @override
  Widget build(BuildContext context) {
    final trip = item.trip;
    final date =
        DateFormat('d MMM yyyy · h:mm a').format(trip.createdAt.toLocal());
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripDetailScreen(
              item: item,
              viewerIsDriver: viewerIsDriver,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _StatusBadge(status: trip.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                viewerIsDriver
                    ? 'For ${item.counterpartyName}'
                    : 'With ${item.counterpartyName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              _RouteRow(
                color: _navy,
                label: 'Pickup',
                address: trip.pickupAddress,
              ),
              const SizedBox(height: 8),
              _RouteRow(
                color: const Color(0xFF2ECC71),
                label: 'Drop',
                address: trip.dropAddress,
              ),
              if (trip.distanceKm != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.straighten,
                        size: 14, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (trip.weightKg != null) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.scale_outlined,
                          size: 14, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.weightKg!.toStringAsFixed(0)} kg',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey.shade400),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final Color color;
  final String label;
  final String address;
  const _RouteRow(
      {required this.color, required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      'completed' => (const Color(0xFFE8F5E9), const Color(0xFF1A7A4A), 'Completed'),
      'cancelled' => (const Color(0xFFFDECEC), const Color(0xFFB23A3A), 'Cancelled'),
      'in_progress' => (_navyLight, _navy, 'In progress'),
      'accepted' => (_navyLight, _navy, 'Accepted'),
      _ => (Colors.grey.shade100, Colors.black54, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _navyLight,
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  color: _navy, size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              'No trips yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your completed and cancelled trips will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          'Could not load trip history. Pull down to retry.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ),
    );
  }
}
