import 'dart:typed_data';

import 'product.dart';

/// Physical classes of trucks that operate on Nigerian downstream routes.
enum TruckClass { tanker33, tanker45, tanker60, lpgBobtail, lpgBridger, atkRefueller }

extension TruckClassX on TruckClass {
  String get label => switch (this) {
        TruckClass.tanker33 => '33,000 L tanker',
        TruckClass.tanker45 => '45,000 L tanker',
        TruckClass.tanker60 => '60,000 L tanker',
        TruckClass.lpgBobtail => 'LPG bobtail (10 MT)',
        TruckClass.lpgBridger => 'LPG bridger (20 MT)',
        TruckClass.atkRefueller => 'ATK refueller (30,000 L)',
      };

  /// Nominal capacity in the unit of the products this truck carries.
  int get capacity => switch (this) {
        TruckClass.tanker33 => 33000,
        TruckClass.tanker45 => 45000,
        TruckClass.tanker60 => 60000,
        TruckClass.lpgBobtail => 10000,
        TruckClass.lpgBridger => 20000,
        TruckClass.atkRefueller => 30000,
      };

  /// Products a truck of this class is built and certified to carry.
  Set<ProductType> get compatibleProducts => switch (this) {
        TruckClass.tanker33 ||
        TruckClass.tanker45 ||
        TruckClass.tanker60 =>
          {ProductType.pms, ProductType.ago, ProductType.dpk},
        TruckClass.lpgBobtail || TruckClass.lpgBridger => {ProductType.lpg},
        TruckClass.atkRefueller => {ProductType.atk},
      };

  String get unit => this == TruckClass.lpgBobtail || this == TruckClass.lpgBridger ? 'kg' : 'L';

  /// Fare multiplier relative to a 33,000 L tanker.
  double get fareFactor => switch (this) {
        TruckClass.tanker33 => 1.0,
        TruckClass.tanker45 => 1.3,
        TruckClass.tanker60 => 1.6,
        TruckClass.lpgBobtail => 1.1,
        TruckClass.lpgBridger => 1.5,
        TruckClass.atkRefueller => 1.4,
      };
}

/// A photo captured during driver onboarding or a periodic re-check.
class CapturedPhoto {
  const CapturedPhoto({required this.label, required this.bytes, required this.takenAt});

  final String label;
  final Uint8List bytes;
  final DateTime takenAt;
}

class Truck {
  const Truck({
    required this.id,
    required this.plate,
    required this.truckClass,
    required this.make,
    required this.year,
    required this.calibrationExpiry,
    this.products = const {},
    this.photos = const [],
  });

  final String id;
  final String plate;
  final TruckClass truckClass;
  final String make;
  final int year;

  /// Expiry of the tank calibration certificate (required at every depot).
  final DateTime calibrationExpiry;

  /// Products the owner has declared this truck carries. Always a subset of the class' compatible set.
  final Set<ProductType> products;
  final List<CapturedPhoto> photos;

  int get capacity => truckClass.capacity;
  String get unit => truckClass.unit;
  bool get calibrationValid => calibrationExpiry.isAfter(DateTime.now());

  String get summary => '${truckClass.label} · $plate';

  Truck copyWith({
    String? plate,
    TruckClass? truckClass,
    String? make,
    int? year,
    DateTime? calibrationExpiry,
    Set<ProductType>? products,
    List<CapturedPhoto>? photos,
  }) {
    return Truck(
      id: id,
      plate: plate ?? this.plate,
      truckClass: truckClass ?? this.truckClass,
      make: make ?? this.make,
      year: year ?? this.year,
      calibrationExpiry: calibrationExpiry ?? this.calibrationExpiry,
      products: products ?? this.products,
      photos: photos ?? this.photos,
    );
  }
}
