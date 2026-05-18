import 'package:flutter/material.dart';
import 'driver_map_screen.dart';
import 'incoming_load_screen.dart';
import '../profile/driver_settings_screen.dart';

const _navy = Color(0xFF003F7D);

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverSettingsScreen()),
          ),
        ),
        title: const Text(
          'TripJio',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_isOnline)
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
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [
            Tab(text: 'Find Loads'),
            Tab(text: 'My Trips'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FindLoadsTab(
            isOnline: _isOnline,
            onToggle: (val) => setState(() => _isOnline = val),
            onMapTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverMapScreen()),
            ),
          ),
          const _MyTripsTab(),
        ],
      ),
    );
  }
}

class _FindLoadsTab extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMapTap;

  const _FindLoadsTab({
    required this.isOnline,
    required this.onToggle,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OnlineToggleBanner(isOnline: isOnline, onToggle: onToggle),
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
        _BottomActions(
          isOnline: isOnline,
          onMapTap: onMapTap,
          onToggle: onToggle,
        ),
      ],
    );
  }
}

class _OnlineToggleBanner extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onToggle;

  const _OnlineToggleBanner({
    required this.isOnline,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.white : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "You're Online" : "You're Offline",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isOnline ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? 'Receiving load requests'
                      : 'Go online to find loads',
                  style: TextStyle(
                    fontSize: 13,
                    color: isOnline ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            onChanged: onToggle,
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
          const Text(
            'Go online to start',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn on availability to see\nnearby load opportunities',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
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
    return Row(
      children: const [
        _StatCard(label: 'Trips', value: '3'),
        SizedBox(width: 10),
        _StatCard(label: 'Hours', value: '4.5'),
        SizedBox(width: 10),
        _StatCard(label: 'Requests', value: '7'),
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
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
            const Text(
              'Nearby Loads',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text(
                'See All',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _TappableLoadCard(
          company: 'Rajesh Textiles',
          location: 'Andheri · 2.4 km',
          vehicleType: 'LCV · 800kg',
          tripDistance: '12 km trip',
          isNew: true,
        ),
        const SizedBox(height: 10),
        _TappableLoadCard(
          company: 'Mehta Traders',
          location: 'Bandra · 4.1 km',
          vehicleType: 'Mini · 400kg',
          tripDistance: '8 km trip',
          isNew: false,
        ),
      ],
    );
  }
}

class _LoadCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isNew ? _navy : Colors.grey.shade200,
          width: isNew ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                company,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              if (isNew)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
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
                location,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vehicleType,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                tripDistance,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onMapTap;
  final ValueChanged<bool> onToggle;

  const _BottomActions({
    required this.isOnline,
    required this.onMapTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
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
                    onPressed: onMapTap,
                    icon: const Icon(Icons.map_outlined, color: Colors.black87, size: 20),
                    label: const Text(
                      'Map',
                      style: TextStyle(color: Colors.black87, fontSize: 15),
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
                    label: const Text(
                      'Refresh',
                      style: TextStyle(color: Colors.white, fontSize: 15),
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
                onPressed: () => onToggle(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Go Online',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
    );
  }
}

// Tappable wrapper around _LoadCard that opens IncomingLoadScreen
class _TappableLoadCard extends StatelessWidget {
  final String company;
  final String location;
  final String vehicleType;
  final String tripDistance;
  final bool isNew;

  const _TappableLoadCard({
    required this.company,
    required this.location,
    required this.vehicleType,
    required this.tripDistance,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IncomingLoadScreen()),
      ),
      child: _LoadCard(
        company: company,
        location: location,
        vehicleType: vehicleType,
        tripDistance: tripDistance,
        isNew: isNew,
      ),
    );
  }
}

// ─── Screen 26: My Trips History ────────────────────────────────────────────

class _MyTripsTab extends StatefulWidget {
  const _MyTripsTab();

  @override
  State<_MyTripsTab> createState() => _MyTripsTabState();
}

class _MyTripsTabState extends State<_MyTripsTab> {
  int _filter = 0; // 0=All, 1=Completed, 2=Cancelled

  static const _trips = [
    _TripRecord(
      status: 'COMPLETED',
      from: 'Andheri East',
      to: 'Bandra West',
      customer: 'Rajesh Sharma · 650kg',
      distance: '12 km',
      time: 'Today, 11:24 AM',
      isCompleted: true,
    ),
    _TripRecord(
      status: 'COMPLETED',
      from: 'Powai',
      to: 'Thane',
      customer: 'Mehta Traders · 400kg',
      distance: '18 km',
      time: 'Today, 09:15 AM',
      isCompleted: true,
    ),
    _TripRecord(
      status: 'CANCELLED',
      from: 'Goregaon',
      to: 'Vashi',
      customer: 'Sharma Logistics · 800kg',
      distance: '22 km',
      time: 'Yesterday',
      isCompleted: false,
    ),
  ];

  List<_TripRecord> get _filtered {
    if (_filter == 1) return _trips.where((t) => t.isCompleted).toList();
    if (_filter == 2) return _trips.where((t) => !t.isCompleted).toList();
    return _trips;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              _FilterChipBtn(label: 'All', selected: _filter == 0, onTap: () => setState(() => _filter = 0)),
              const SizedBox(width: 8),
              _FilterChipBtn(label: 'Completed', selected: _filter == 1, onTap: () => setState(() => _filter = 1)),
              const SizedBox(width: 8),
              _FilterChipBtn(label: 'Cancelled', selected: _filter == 2, onTap: () => setState(() => _filter = 2)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(
                  child: Text('No trips found', style: TextStyle(color: Colors.black45)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _TripHistoryCard(trip: _filtered[i]),
                ),
        ),
      ],
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
                    style: TextStyle(
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
                style: const TextStyle(fontSize: 12, color: Colors.black45),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
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
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
              Text(trip.distance,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
