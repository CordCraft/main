import 'product.dart';

/// Product an offtaker is offering for lifting at a specific depot.
class ProductListing {
  const ProductListing({
    required this.id,
    required this.offtakerId,
    required this.offtakerName,
    required this.depotId,
    required this.product,
    required this.pricePerUnit,
    required this.availableQuantity,
    required this.minQuantity,
    required this.proofId,
    required this.proofReference,
    required this.proofExpiresAt,
    required this.createdAt,
    this.active = true,
  });

  final String id;
  final String offtakerId;
  final String offtakerName;
  final String depotId;
  final ProductType product;
  final double pricePerUnit;
  final int availableQuantity;
  final int minQuantity;
  final String proofId;
  final String proofReference;
  final DateTime proofExpiresAt;
  final DateTime createdAt;
  final bool active;

  bool get proofValid => proofExpiresAt.isAfter(DateTime.now());

  /// A listing is only shown to buyers while its proof of product is valid.
  bool get isVisible => active && proofValid && availableQuantity > 0;

  bool canFill(int quantity) => quantity >= minQuantity && quantity <= availableQuantity;

  ProductListing copyWith({
    double? pricePerUnit,
    int? availableQuantity,
    int? minQuantity,
    bool? active,
  }) {
    return ProductListing(
      id: id,
      offtakerId: offtakerId,
      offtakerName: offtakerName,
      depotId: depotId,
      product: product,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      minQuantity: minQuantity ?? this.minQuantity,
      proofId: proofId,
      proofReference: proofReference,
      proofExpiresAt: proofExpiresAt,
      createdAt: createdAt,
      active: active ?? this.active,
    );
  }
}
