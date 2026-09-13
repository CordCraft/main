import 'package:flutter/material.dart';

/// Downstream petroleum products Ontero moves.
enum ProductType { pms, ago, dpk, lpg, atk }

extension ProductTypeX on ProductType {
  String get code => switch (this) {
        ProductType.pms => 'PMS',
        ProductType.ago => 'AGO',
        ProductType.dpk => 'DPK',
        ProductType.lpg => 'LPG',
        ProductType.atk => 'ATK',
      };

  String get label => switch (this) {
        ProductType.pms => 'Petrol (PMS)',
        ProductType.ago => 'Diesel (AGO)',
        ProductType.dpk => 'Kerosene (DPK)',
        ProductType.lpg => 'Cooking Gas (LPG)',
        ProductType.atk => 'Aviation Fuel (ATK)',
      };

  String get shortLabel => switch (this) {
        ProductType.pms => 'Petrol',
        ProductType.ago => 'Diesel',
        ProductType.dpk => 'Kerosene',
        ProductType.lpg => 'Cooking gas',
        ProductType.atk => 'Jet fuel',
      };

  /// LPG is sold by weight, everything else by volume.
  String get unit => this == ProductType.lpg ? 'kg' : 'L';

  IconData get icon => switch (this) {
        ProductType.pms => Icons.local_gas_station,
        ProductType.ago => Icons.local_shipping,
        ProductType.dpk => Icons.light_mode,
        ProductType.lpg => Icons.propane_tank,
        ProductType.atk => Icons.flight,
      };

  Color get color => switch (this) {
        ProductType.pms => const Color(0xFF2E7D32),
        ProductType.ago => const Color(0xFF5D4037),
        ProductType.dpk => const Color(0xFFF9A825),
        ProductType.lpg => const Color(0xFF1565C0),
        ProductType.atk => const Color(0xFF6A1B9A),
      };
}
