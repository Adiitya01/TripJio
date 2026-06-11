import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../models/request_model.dart';

class RequestRepository {
  final SupabaseClient _client = SupabaseService.client;

  // ─── Load Owner: Send a request to a driver ───────────────────────────────

  Future<RequestModel> createRequest({
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
    // Uses the auth + validation + rate-limited server RPC.
    final response = await _client.rpc('create_request_safe', params: {
      'p_load_owner_id': loadOwnerId,
      'p_driver_id': driverId,
      'p_pickup_address': pickupAddress,
      'p_drop_address': dropAddress,
      'p_pickup_lat': pickupLat,
      'p_pickup_lng': pickupLng,
      'p_drop_lat': dropLat,
      'p_drop_lng': dropLng,
      'p_goods_description': goodsDescription,
      'p_weight_kg': weightKg,
    });
    return RequestModel.fromMap(response as Map<String, dynamic>);
  }

  // ─── Driver: Listen for incoming requests (Realtime) ─────────────────────

  Stream<RequestModel> listenForIncomingRequests(String driverId) {
    final controller = StreamController<RequestModel>.broadcast();

    final channel = _client.channel('incoming_requests_$driverId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'driver_id',
        value: driverId,
      ),
      callback: (payload) async {
        final request = RequestModel.fromMap(payload.newRecord);

        // Fire local notification to driver
        await NotificationService().notifyNewLoadRequest(
          loadOwnerName: 'Load Owner',
          pickup: request.pickupAddress,
          drop: request.dropAddress,
        );

        controller.add(request);
      },
    ).subscribe();

    controller.onCancel = () => _client.removeChannel(channel);
    return controller.stream;
  }

  // ─── Driver: Accept or reject a request ───────────────────────────────────

  /// Reject a request (driver-side rejection).
  Future<void> respondToRequest({
    required String requestId,
    required bool accepted,
  }) async {
    if (accepted) {
      throw StateError('Use acceptRequestAtomic() for accepts');
    }
    await _client
        .from('requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }

  /// Race-safe cancel by the load owner. Throws if driver already accepted.
  /// Returns the resulting status ('cancelled' or previous if no-op).
  Future<String> cancelRequestByLoadOwner({
    required String requestId,
    required String callerId,
  }) async {
    final result = await _client.rpc('cancel_request_safe', params: {
      'p_request_id': requestId,
      'p_caller_id': callerId,
    });
    return result as String;
  }

  /// Atomic accept — updates request, marks driver busy, creates trip.
  /// All in one transaction so partial failures don't leave orphan state.
  /// Returns the new trip ID.
  Future<String> acceptRequestAtomic(String requestId) async {
    final tripId = await _client.rpc(
      'accept_request_and_create_trip',
      params: {'p_request_id': requestId},
    );
    return tripId as String;
  }

  // ─── Load Owner: Listen for request status changes (Realtime) ─────────────

  Stream<RequestModel> listenToRequestStatus(String requestId) {
    final controller = StreamController<RequestModel>.broadcast();

    final channel = _client.channel('request_status_$requestId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: requestId,
      ),
      callback: (payload) async {
        final request = RequestModel.fromMap(payload.newRecord);

        // Fire notification when driver accepts
        if (request.status == 'accepted') {
          await NotificationService().notifyRequestAccepted(
            driverName: 'Driver',
            vehicleNumber: '',
          );
        }

        controller.add(request);
      },
    ).subscribe();

    controller.onCancel = () => _client.removeChannel(channel);
    return controller.stream;
  }

  // ─── Fetch active request for load owner ──────────────────────────────────

  Future<RequestModel?> getActiveRequest(String loadOwnerId) async {
    final response = await _client
        .from('requests')
        .select()
        .eq('load_owner_id', loadOwnerId)
        .inFilter('status', ['pending', 'accepted'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return RequestModel.fromMap(response);
  }
}
