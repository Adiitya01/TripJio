import 'package:flutter_test/flutter_test.dart';
import 'package:tripjio/core/services/distance_service.dart';

void main() {
  group('Haversine distance', () {
    test('Pune to Mumbai is approximately 117 km (straight line)', () {
      // Pune: 18.5204, 73.8567 — Mumbai: 19.0760, 72.8777
      // Great-circle distance ~117 km (road distance is ~148 km)
      final km = DistanceService.distanceInKm(18.5204, 73.8567, 19.0760, 72.8777);
      expect(km, greaterThan(110));
      expect(km, lessThan(125));
    });

    test('Same point returns 0', () {
      expect(
        DistanceService.distanceInMeters(18.52, 73.85, 18.52, 73.85),
        equals(0),
      );
    });

    test('1 km north is approximately 1000 meters', () {
      // 0.009° latitude ≈ 1 km
      final meters = DistanceService.distanceInMeters(18.5, 73.85, 18.509, 73.85);
      expect(meters, greaterThan(950));
      expect(meters, lessThan(1050));
    });

    test('Antipodal points return ~20000 km', () {
      // Roughly opposite sides of Earth
      final km = DistanceService.distanceInKm(0, 0, 0, 180);
      expect(km, greaterThan(19000));
      expect(km, lessThan(21000));
    });

    test('Negative coordinates work', () {
      // Sydney to LA
      final km = DistanceService.distanceInKm(-33.8688, 151.2093, 34.0522, -118.2437);
      expect(km, greaterThan(12000));
      expect(km, lessThan(13000));
    });
  });

  group('ETA calculation', () {
    test('5 km at 25 km/h with 20% buffer = 15 minutes', () {
      final minutes = DistanceService.etaInMinutes(5.0);
      // (5 / 25) * 60 * 1.2 = 14.4 → ceil() = 15
      expect(minutes, equals(15));
    });

    test('10 km = 29 minutes', () {
      expect(DistanceService.etaInMinutes(10.0), equals(29));
    });

    test('0 km = 0 minutes', () {
      expect(DistanceService.etaInMinutes(0), equals(0));
    });

    test('ETA label under 60 min', () {
      expect(DistanceService.etaLabel(5.0), equals('15 min'));
    });

    test('ETA label over 60 min formats as hours', () {
      // 50 km → (50/25)*60*1.2 = 144 min = 2 hr 24 min
      expect(DistanceService.etaLabel(50.0), contains('hr'));
    });
  });

  group('Distance label formatting', () {
    test('Under 1km shows in meters', () {
      final label = DistanceService.distanceLabel(18.5, 73.85, 18.504, 73.85);
      expect(label, contains('m'));
      expect(label, isNot(contains('km')));
    });

    test('Over 1km shows in km', () {
      final label = DistanceService.distanceLabel(18.5, 73.85, 18.55, 73.85);
      expect(label, contains('km'));
    });
  });

  group('Fare estimation', () {
    test('Mini Truck 5 km no weight surcharge', () {
      // 50 base + 5*12 = 110
      final fare = DistanceService.estimateFare(
        distanceKm: 5.0,
        vehicleType: 'Mini Truck',
      );
      expect(fare, equals(110.0));
    });

    test('Mini Truck 5 km 800 kg = base + km + surcharge', () {
      // 50 + 5*12 + 0.3 tonne * 10 * 5 = 50 + 60 + 15 = 125
      final fare = DistanceService.estimateFare(
        distanceKm: 5.0,
        vehicleType: 'Mini Truck',
        weightKg: 800,
      );
      expect(fare, equals(125.0));
    });

    test('LCV rate is 16/km', () {
      // 50 + 10*16 = 210 (no weight surcharge under 500kg)
      final fare = DistanceService.estimateFare(
        distanceKm: 10.0,
        vehicleType: 'LCV',
      );
      expect(fare, equals(210.0));
    });

    test('HCV rate is 22/km', () {
      // 50 + 10*22 = 270
      final fare = DistanceService.estimateFare(
        distanceKm: 10.0,
        vehicleType: 'HCV',
      );
      expect(fare, equals(270.0));
    });

    test('Container rate is 28/km', () {
      // 50 + 10*28 = 330
      final fare = DistanceService.estimateFare(
        distanceKm: 10.0,
        vehicleType: 'Container',
      );
      expect(fare, equals(330.0));
    });

    test('Unknown vehicle type falls back to default ₹15/km', () {
      // 50 + 5*15 = 125
      final fare = DistanceService.estimateFare(
        distanceKm: 5.0,
        vehicleType: 'UnknownType',
      );
      expect(fare, equals(125.0));
    });

    test('Weight below 500 kg has no surcharge', () {
      // 50 + 5*12 = 110 (no surcharge for 400 kg)
      final fare = DistanceService.estimateFare(
        distanceKm: 5.0,
        vehicleType: 'Mini Truck',
        weightKg: 400,
      );
      expect(fare, equals(110.0));
    });

    test('Fare label formats with ₹', () {
      final label = DistanceService.fareLabel(
        distanceKm: 5.0,
        vehicleType: 'Mini Truck',
      );
      expect(label, contains('₹'));
      expect(label, contains('110'));
    });
  });
}
