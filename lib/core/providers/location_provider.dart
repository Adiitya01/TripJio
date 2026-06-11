import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/location_repository.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

/// Provider for the LocationRepository instance
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

/// Provider for the LocationService instance
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// StreamProvider that listens to the device's foreground GPS updates
final foregroundLocationStreamProvider = StreamProvider<Position>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.getLocationStream();
});

/// Family StreamProvider that takes a driverId and listens to their Realtime updates from Supabase
final driverRealtimeLocationProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, driverId) {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.listenToDriverLocation(driverId);
});
