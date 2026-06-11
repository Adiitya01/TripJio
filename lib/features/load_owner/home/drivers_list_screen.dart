import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/driver_repository.dart';
import '../providers/load_owner_provider.dart';
import 'send_request_screen.dart';

const _navy = Color(0xFF003F7D);

class DriversListScreen extends ConsumerStatefulWidget {
  const DriversListScreen({super.key});

  @override
  ConsumerState<DriversListScreen> createState() =>
      _DriversListScreenState();
}

class _DriversListScreenState extends ConsumerState<DriversListScreen> {
  static const _labels = ['All', 'Mini Truck', 'LCV', 'HCV'];

  String? _vehicleFilter(int index) {
    switch (index) {
      case 1:
        return 'Mini Truck';
      case 2:
        return 'LCV';
      case 3:
        return 'HCV';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterIndex = ref.watch(vehicleTypeFilterProvider);
    final userLocation = ref.watch(userLocationProvider);

    final driversAsync = userLocation == null
        ? const AsyncValue<List<NearbyDriver>>.loading()
        : ref.watch(nearbyDriversProvider(userLocation));

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
          'Nearby Trucks',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: List.generate(
                _labels.length,
                (i) => Padding(
                  padding: EdgeInsets.only(
                      right: i < _labels.length - 1 ? 8 : 0),
                  child: _FilterChip(
                    label: _labels[i],
                    selected: filterIndex == i,
                    onTap: () => ref
                        .read(vehicleTypeFilterProvider.notifier)
                        .state = i,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: driversAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _navy)),
              error: (e, _) => Center(
                child: Text('Failed to load drivers',
                    style: TextStyle(color: Colors.red.shade700)),
              ),
              data: (drivers) {
                final vFilter = _vehicleFilter(filterIndex);
                final filtered = vFilter == null
                    ? drivers
                    : drivers
                        .where((d) => d.vehicleType == vFilter)
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No online drivers nearby right now.\nTry again in a few minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.black54, fontSize: 14),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) => _DriverCard(
                    driver: filtered[i],
                    onContact: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SendRequestScreen(
                          driver: _DriverData(
                            userId: filtered[i].userId,
                            name: filtered[i].name,
                            vehicle: filtered[i].vehicleType,
                            vehicleType: filtered[i].vehicleType,
                            number: filtered[i].vehicleNumber,
                            capacity: filtered[i].capacity,
                            distance:
                                '${filtered[i].distanceKm.toStringAsFixed(1)} km',
                            distanceKm: filtered[i].distanceKm,
                            rating: filtered[i].rating,
                            trips: filtered[i].totalTrips,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _navy : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final NearbyDriver driver;
  final VoidCallback onContact;

  const _DriverCard({required this.driver, required this.onContact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
            ),
            child:
                const Icon(Icons.person, color: Colors.black45, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        driver.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          driver.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${driver.vehicleNumber} · ${driver.vehicleType}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2ECC71)),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Online · ${driver.distanceKm.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A7A4A),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onContact,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Contact',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverData {
  final String userId;
  final String name;
  final String vehicle;
  final String vehicleType;
  final String number;
  final String capacity;
  final String distance;
  final double distanceKm;
  final double rating;
  final int trips;

  const _DriverData({
    required this.userId,
    required this.name,
    required this.vehicle,
    required this.vehicleType,
    required this.number,
    required this.capacity,
    required this.distance,
    required this.distanceKm,
    required this.rating,
    required this.trips,
  });
}
