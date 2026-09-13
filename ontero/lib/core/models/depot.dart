import 'package:latlong2/latlong.dart';

import 'product.dart';

/// A loading depot or refinery gantry where trucks lift product.
class Depot {
  const Depot({
    required this.id,
    required this.name,
    required this.operator,
    required this.city,
    required this.state,
    required this.location,
    required this.products,
    this.address = '',
  });

  final String id;
  final String name;
  final String operator;
  final String city;
  final String state;
  final LatLng location;
  final Set<ProductType> products;
  final String address;

  String get shortLocation => '$city, $state';
}
