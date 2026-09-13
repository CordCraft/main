import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../models/truck.dart';

/// Pricing rules for haulage, escrow releases and the platform cut.
class Pricing {
  Pricing._();

  /// Onterra keeps this share of every driver fare and product payment.
  static const platformFeeRate = 0.05;

  /// Share of the driver fare released once the truck is loaded at the depot.
  static const driverLiftReleaseShare = 0.5;

  static const _baseFare = 150000.0; // NGN, covers loading day and depot fees
  static const _perKm = 1200.0; // NGN per road km for a 33,000 L tanker
  static const _roadFactor = 1.3; // straight line to road distance

  static double straightLineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }

  static double roadKm(LatLng a, LatLng b) => straightLineKm(a, b) * _roadFactor;

  static double driverFare(TruckClass truckClass, double roadKm) {
    final raw = (_baseFare + _perKm * roadKm) * truckClass.fareFactor;
    return (raw / 1000).round() * 1000; // round to the nearest thousand naira
  }

  static double platformFee(double gross) => gross * platformFeeRate;

  static double netOfFee(double gross) => gross - platformFee(gross);

  static double _rad(double deg) => deg * pi / 180;
}
