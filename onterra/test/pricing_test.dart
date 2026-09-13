import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:onterra/core/models/truck.dart';
import 'package:onterra/core/services/pricing.dart';

void main() {
  group('Pricing', () {
    test('Apapa to Ibadan is roughly 120 km straight line', () {
      final km = Pricing.straightLineKm(const LatLng(6.4386, 3.3620), const LatLng(7.3775, 3.9470));
      expect(km, closeTo(122, 6));
    });

    test('road distance applies the 1.3 factor', () {
      const a = LatLng(6.0, 3.0);
      const b = LatLng(7.0, 3.0);
      expect(Pricing.roadKm(a, b), closeTo(Pricing.straightLineKm(a, b) * 1.3, 0.001));
    });

    test('fare rounds to the nearest thousand and scales by truck class', () {
      final small = Pricing.driverFare(TruckClass.tanker33, 100);
      final big = Pricing.driverFare(TruckClass.tanker60, 100);
      expect(small % 1000, 0);
      expect(small, 270000);
      expect(big, greaterThan(small));
    });

    test('platform fee is five percent', () {
      expect(Pricing.platformFee(1000000), 50000);
      expect(Pricing.netOfFee(1000000), 950000);
    });
  });
}
