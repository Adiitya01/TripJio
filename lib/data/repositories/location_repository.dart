import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

class LocationRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Update the driver's location in the Supabase 'drivers' table
  Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _client.from('drivers').update({
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', driverId);
    } catch (e) {
      throw Exception('Failed to update driver location: $e');
    }
  }

  /// Lightweight heartbeat — refreshes updated_at only.
  /// Called every 60s by online drivers so a parked truck stays visible
  /// and crashed apps auto-disappear after the freshness window expires.
  Future<void> heartbeat(String driverId) async {
    try {
      await _client.rpc('driver_heartbeat', params: {'driver_id': driverId});
    } catch (_) {/* silent — next tick will retry */}
  }

  /// Listen to real-time location updates for a specific driver
  /// Returns a stream of coordinate maps: {'latitude': double, 'longitude': double}
  Stream<Map<String, dynamic>> listenToDriverLocation(String driverId) {
    // The stream Controller to yield parsed updates
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    final channel = _client.channel('public:drivers:user_id=eq.$driverId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'drivers',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: driverId,
      ),
      callback: (PostgresChangePayload payload) {
        final newRecord = payload.newRecord;
        if (newRecord.containsKey('latitude') &&
            newRecord.containsKey('longitude')) {
          controller.add({
            'latitude': newRecord['latitude'],
            'longitude': newRecord['longitude'],
            'updated_at': newRecord['updated_at'],
          });
        }
      },
    ).subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
