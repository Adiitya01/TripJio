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

  /// Driver-only override for when the pinned drop location is wrong or the
  /// site is larger than the arrival radius. Completes the trip but flags it
  /// for review, recording where the driver actually was and how far that is
  /// from the pinned drop point.
  Future<void> completeTripFlagged({
    required String tripId,
    required double lat,
    required double lng,
    required double distanceMeters,
  }) async {
    final callerId = FirebaseAuth.instance.currentUser?.uid;
    await _client.rpc('complete_trip_flagged', params: {
      'p_trip_id': tripId,
      'p_caller_id': callerId,
      'p_lat': lat,
      'p_lng': lng,
      'p_distance_m': distanceMeters,
    });
  }

  /// Stamps the moment the driver confirms they've collected the goods.
  /// Used by both apps to switch from the pickup leg to the drop leg.
  Future<void> markPickupConfirmed(String tripId) async {
    await _client.from('trips').update({
      'pickup_confirmed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', tripId);
  }

  /// Fetches a specific trip by id. Used to disambiguate cancelled vs
  /// completed when the active-trip lookup returns null after a status change.
  Future<TripModel?> getTripById(String tripId) async {
    final response = await _client
        .from('trips')
        .select()
        .eq('id', tripId)
        .maybeSingle();
    if (response == null) return null;
    return TripModel.fromMap(response);
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

        // Fire notifications based on status.
        // NOTE: total_trips is incremented server-side inside complete_trip;
        // do NOT increment here or every observer would double-count (and
        // could bump an arbitrary driver's count).
        if (trip.status == 'completed') {
          await NotificationService().notifyTripCompleted(
            distance: trip.distanceKm?.toStringAsFixed(1) ?? '?',
          );
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

  // ─── Get trip history for load owner ─────────────────────────────────────

  Future<List<TripModel>> getLoadOwnerTrips(String loadOwnerId,
      {int limit = 50}) async {
    final response = await _client
        .from('trips')
        .select()
        .eq('load_owner_id', loadOwnerId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((e) => TripModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Trip history enriched with counterparty (other-side) name & phone ──

  Future<List<TripHistoryItem>> getTripHistory({
    required String userId,
    required bool isDriver,
    int limit = 50,
  }) async {
    final trips = isDriver
        ? await getDriverTrips(userId, limit: limit)
        : await getLoadOwnerTrips(userId, limit: limit);
    if (trips.isEmpty) return const [];
    final counterIds = trips
        .map((t) => isDriver ? t.loadOwnerId : t.driverId)
        .toSet()
        .toList();
    final usersRows = await _client
        .from('users')
        .select('id, name, phone')
        .inFilter('id', counterIds);
    final byId = <String, Map<String, dynamic>>{
      for (final u in (usersRows as List).cast<Map<String, dynamic>>())
        u['id'] as String: u,
    };
    return trips.map((t) {
      final counterId = isDriver ? t.loadOwnerId : t.driverId;
      final u = byId[counterId];
      return TripHistoryItem(
        trip: t,
        counterpartyName: (u?['name'] as String?) ?? 'Unknown',
        counterpartyPhone: u?['phone'] as String?,
      );
    }).toList();
  }
}

/// A trip plus the display name (and phone) of the *other* party from the
/// caller's perspective — used by the shared trip-history list.
class TripHistoryItem {
  final TripModel trip;
  final String counterpartyName;
  final String? counterpartyPhone;

  const TripHistoryItem({
    required this.trip,
    required this.counterpartyName,
    this.counterpartyPhone,
  });
}
