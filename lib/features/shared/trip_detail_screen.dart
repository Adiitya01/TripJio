import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/trip_repository.dart';

const _navy = Color(0xFF003F7D);
const _navyLight = Color(0xFFE6EEF8);

class TripDetailScreen extends StatelessWidget {
  final TripHistoryItem item;
  final bool viewerIsDriver;

  const TripDetailScreen({
    super.key,
    required this.item,
    required this.viewerIsDriver,
  });

  String _fmt(DateTime? dt) => dt == null
      ? '—'
      : DateFormat('d MMM yyyy · h:mm a').format(dt.toLocal());

  @override
  Widget build(BuildContext context) {
    final trip = item.trip;
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
          'Trip details',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _StatusBanner(status: trip.status),
          const SizedBox(height: 16),
          _Section(
            title: 'Route',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Point(
                  color: _navy,
                  label: 'Pickup',
                  address: trip.pickupAddress,
                ),
                const SizedBox(height: 10),
                _Point(
                  color: const Color(0xFF2ECC71),
                  label: 'Drop',
                  address: trip.dropAddress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: viewerIsDriver ? 'Load owner' : 'Driver',
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _navyLight,
                  ),
                  child: const Icon(Icons.person, color: _navy, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.counterpartyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (item.counterpartyPhone != null &&
                          item.counterpartyPhone!.isNotEmpty)
                        Text(
                          item.counterpartyPhone!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                if (item.counterpartyPhone != null &&
                    item.counterpartyPhone!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, color: Color(0xFF2ECC71)),
                    tooltip: 'Call',
                    onPressed: () async {
                      final uri = Uri(
                          scheme: 'tel', path: item.counterpartyPhone);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Trip info',
            child: Column(
              children: [
                _InfoRow(label: 'Booked', value: _fmt(trip.createdAt)),
                if (trip.pickupConfirmedAt != null)
                  _InfoRow(
                      label: 'Pickup confirmed',
                      value: _fmt(trip.pickupConfirmedAt)),
                if (trip.completedAt != null)
                  _InfoRow(
                      label: 'Completed',
                      value: _fmt(trip.completedAt)),
                if (trip.distanceKm != null)
                  _InfoRow(
                      label: 'Distance',
                      value: '${trip.distanceKm!.toStringAsFixed(1)} km'),
                if (trip.weightKg != null)
                  _InfoRow(
                      label: 'Weight',
                      value: '${trip.weightKg!.toStringAsFixed(0)} kg'),
                if (trip.goodsDescription != null &&
                    trip.goodsDescription!.isNotEmpty)
                  _InfoRow(label: 'Goods', value: trip.goodsDescription!),
                _InfoRow(label: 'Trip ID', value: trip.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final Color color;
  final String label;
  final String address;
  const _Point({
    required this.color,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 15,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String label) = switch (status) {
      'completed' => (
        const Color(0xFFE8F5E9),
        const Color(0xFF1A7A4A),
        Icons.check_circle,
        'Completed',
      ),
      'cancelled' => (
        const Color(0xFFFDECEC),
        const Color(0xFFB23A3A),
        Icons.cancel,
        'Cancelled',
      ),
      'in_progress' => (
        _navyLight,
        _navy,
        Icons.local_shipping,
        'In progress',
      ),
      'accepted' => (_navyLight, _navy, Icons.task_alt, 'Accepted'),
      _ => (Colors.grey.shade100, Colors.black54, Icons.info_outline, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
