import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/distance_service.dart';
import '../models/trip_model.dart';

class TripRepository {
  final SupabaseClient _client = SupabaseService.client;

  // ─── Create trip when request is accepted ─────────────────────────────────

  Future<TripModel> createTrip({
    required String loadOwnerId,
    required String driverId,
    required String pickupAddress,
    required String dropAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    String? goodsDescription,
    double? weightKg,
  }) async {
    final distanceKm = DistanceService.distanceInKm(
        pickupLat, pickupLng, dropLat, dropLng);

    final data = {
      'load_owner_id': loadOwnerId,
      'driver_id': driverId,
      'pickup_address': pickupAddress,
      'drop_address': dropAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'drop_lat': dropLat,
      'drop_lng': dropLng,
      'status': 'accepted',
      'distance_km': distanceKm,
      'goods_description': goodsDescription,
      'weight_kg': weightKg,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response =
        await _client.from('trips').insert(data).select().single();
    return TripModel.fromMap(response);
  }

  // ─── Update trip status ────────────────────────────────────────────────────

  /// Valid transitions:
  /// accepted → in_progress → completed
  /// accepted → cancelled
  /// Uses RPCs for complete/cancel so the driver's is_busy flag is also released.
  Future<void> updateStatus(String tripId, String status) async {
    final callerId = FirebaseAuth.instance.currentUser?.uid;
    if (status == 'completed') {
      await _client.rpc('complete_trip',
          params: {'p_trip_id': tripId, 'p_caller_id': callerId});
    } else if (status == 'cancelled') {
      await _client.rpc('cancel_trip',
          params: {'p_trip_id': tripId, 'p_caller_id': callerId});
    } else {
      await _client.from('trips').update({'status': status}).eq('id', tripId);
    }
  }

  /// Returns the user's currently active trip (if any).
  /// Used on app start to resume a session that was interrupted.
  Future<TripModel?> getActiveTripForUser(String userId) async {
    final response = await _client.rpc(
      'get_active_trip',
      params: {'p_user_id': userId},
    );
    final list = response as List;
    if (list.isEmpty) return null;
    return TripModel.fromMap(list.first as Map<String, dynamic>);
  }

  // ─── Listen to trip status (Realtime) ─────────────────────────────────────

  Stream<TripModel> listenToTrip(String tripId) {
    final controller = StreamController<TripModel>.broadcast();

    final channel = _client.channel('trip_$tripId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'trips',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: tripId,
      ),
      callback: (payload) async {
        final trip = TripModel.fromMap(payload.newRecord);

        // Fire notifications based on status
        if (trip.status == 'completed') {
          await NotificationService().notifyTripCompleted(
            distance: trip.distanceKm?.toStringAsFixed(1) ?? '?',
          );
          // Increment driver total_trips in Supabase
          await _client.rpc('increment_driver_trips',
              params: {'driver_id': trip.driverId});
        }

        controller.add(trip);
      },
    ).subscribe();

    controller.onCancel = () => _client.removeChannel(channel);
    return controller.stream;
  }

  // ─── Get trip history for driver ──────────────────────────────────────────

  Future<List<TripModel>> getDriverTrips(String driverId,
      {int limit = 20}) async {
    final response = await _client
        .from('trips')
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((e) => TripModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Get active trip ──────────────────────────────────────────────────────

  Future<TripModel?> getActiveTrip(String userId) async {
    final response = await _client
        .from('trips')
        .select()
        .or('driver_id.eq.$userId,load_owner_id.eq.$userId')
        .inFilter('status', ['accepted', 'in_progress'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return TripModel.fromMap(response);
  }
}
