import 'package:flutter_riverpod/flutter_riverpod.dart';

// Driver online/offline toggle — shared across all driver screens
final driverOnlineProvider = StateProvider<bool>((ref) => false);

// Trip history filter: 0=All, 1=Completed, 2=Cancelled
final tripFilterProvider = StateProvider<int>((ref) => 0);
