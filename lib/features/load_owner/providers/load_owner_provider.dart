import 'package:flutter_riverpod/flutter_riverpod.dart';

// Vehicle type filter on home map: 0=All, 1=Mini, 2=LCV, 3=HCV
final vehicleTypeFilterProvider = StateProvider<int>((ref) => 0);

// Index of the truck pin currently selected on the map
final selectedTruckPinProvider = StateProvider<int?>((ref) => null);
