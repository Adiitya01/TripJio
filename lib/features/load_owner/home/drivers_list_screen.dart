import 'package:flutter/material.dart';
import 'send_request_screen.dart';

const _navy = Color(0xFF003F7D);

class DriversListScreen extends StatefulWidget {
  const DriversListScreen({super.key});

  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  int _filter = 0; // 0=All, 1=Mini, 2=LCV, 3=HCV

  static const _allDrivers = [
    _DriverInfo(name: 'Suresh Patil', vehicle: 'Mini Truck', number: 'MH 14 AB 1234', capacity: '800 kg', distance: '2.4', rating: 4.8, trips: 234, type: 1),
    _DriverInfo(name: 'Ramesh Kumar', vehicle: 'LCV', number: 'MH 12 CD 5678', capacity: '1200 kg', distance: '3.7', rating: 4.6, trips: 187, type: 2),
    _DriverInfo(name: 'Anil Yadav', vehicle: 'HCV', number: 'MH 04 EF 9012', capacity: '2500 kg', distance: '5.1', rating: 4.9, trips: 312, type: 3),
    _DriverInfo(name: 'Vikram Singh', vehicle: 'Mini Truck', number: 'MH 01 GH 3456', capacity: '600 kg', distance: '6.3', rating: 4.5, trips: 142, type: 1),
    _DriverInfo(name: 'Deepak Joshi', vehicle: 'LCV', number: 'MH 06 IJ 7890', capacity: '1500 kg', distance: '7.8', rating: 4.7, trips: 221, type: 2),
  ];

  static const _labels = ['All', 'Mini', 'LCV', 'HCV'];

  List<_DriverInfo> get _filtered {
    if (_filter == 0) return _allDrivers;
    return _allDrivers.where((d) => d.type == _filter).toList();
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
                  padding: EdgeInsets.only(right: i < _labels.length - 1 ? 8 : 0),
                  child: _FilterChip(
                    label: _labels[i],
                    selected: _filter == i,
                    onTap: () => setState(() => _filter = i),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _DriverCard(
                driver: _filtered[i],
                onContact: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SendRequestScreen(
                      driver: _DriverData(
                        name: _filtered[i].name,
                        vehicle: _filtered[i].vehicle,
                        number: _filtered[i].number,
                        capacity: _filtered[i].capacity,
                        distance: '${_filtered[i].distance} km',
                        rating: _filtered[i].rating,
                        trips: _filtered[i].trips,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverInfo {
  final String name;
  final String vehicle;
  final String number;
  final String capacity;
  final String distance;
  final double rating;
  final int trips;
  final int type; // 1=Mini, 2=LCV, 3=HCV

  const _DriverInfo({
    required this.name,
    required this.vehicle,
    required this.number,
    required this.capacity,
    required this.distance,
    required this.rating,
    required this.trips,
    required this.type,
  });
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
  final _DriverInfo driver;
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
            child: const Icon(Icons.person, color: Colors.black45, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          driver.rating.toString(),
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${driver.number} · ${driver.vehicle}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                            color: Color(0xFF2ECC71),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Online · ${driver.distance} km away',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A7A4A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onContact,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Contact',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
  final String name;
  final String vehicle;
  final String number;
  final String capacity;
  final String distance;
  final double rating;
  final int trips;

  const _DriverData({
    required this.name,
    required this.vehicle,
    required this.number,
    required this.capacity,
    required this.distance,
    required this.rating,
    required this.trips,
  });
}
