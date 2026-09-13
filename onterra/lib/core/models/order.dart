import 'package:latlong2/latlong.dart';

import 'depot.dart';
import 'product.dart';
import 'truck.dart';

/// Lifecycle of a delivery. Each step is gated by a specific party.
///
/// customer  → awaitingDriver
/// driver    → driverAccepted
/// customer  → driverFunded   (driver fare into escrow)
/// customer  → productFunded  (product cost into escrow)
/// offtaker  → atlIssued      (authority to lift raised on the driver)
/// driver    → lifted         (50% of fare + 100% of product cost released)
/// driver    → delivered
/// customer  → completed      (remaining 50% of fare released)
enum OrderStatus {
  awaitingDriver,
  driverAccepted,
  driverFunded,
  productFunded,
  atlIssued,
  lifted,
  delivered,
  completed,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.awaitingDriver => 'Finding driver',
        OrderStatus.driverAccepted => 'Driver accepted',
        OrderStatus.driverFunded => 'Driver secured',
        OrderStatus.productFunded => 'Product paid',
        OrderStatus.atlIssued => 'ATL issued',
        OrderStatus.lifted => 'Loaded at depot',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.completed => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
      };

  bool get isOpen => this != OrderStatus.completed && this != OrderStatus.cancelled;

  /// Steps shown on the tracking timeline, in order.
  static const timeline = [
    OrderStatus.awaitingDriver,
    OrderStatus.driverAccepted,
    OrderStatus.driverFunded,
    OrderStatus.productFunded,
    OrderStatus.atlIssued,
    OrderStatus.lifted,
    OrderStatus.delivered,
    OrderStatus.completed,
  ];

  int get stepIndex => OrderStatusX.timeline.indexOf(this);
}

class DeliveryPoint {
  const DeliveryPoint({required this.label, required this.address, required this.location});

  final String label;
  final String address;
  final LatLng location;
}

/// Authority To Lift: the document a depot needs before it loads a truck.
class Atl {
  const Atl({
    required this.number,
    required this.issuedAt,
    required this.issuedBy,
    required this.depotId,
    required this.product,
    required this.quantity,
    required this.truckPlate,
    required this.driverName,
    required this.validUntil,
  });

  final String number;
  final DateTime issuedAt;
  final String issuedBy;
  final String depotId;
  final ProductType product;
  final int quantity;
  final String truckPlate;
  final String driverName;
  final DateTime validUntil;
}

class OrderEvent {
  const OrderEvent({required this.status, required this.at, required this.note});

  final OrderStatus status;
  final DateTime at;
  final String note;
}

class Order {
  const Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.product,
    required this.quantity,
    required this.depot,
    required this.destination,
    required this.distanceKm,
    required this.createdAt,
    required this.status,
    required this.driverFare,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.truckClass,
    this.truckPlate,
    this.listingId,
    this.offtakerId,
    this.offtakerName,
    this.unitPrice,
    this.atl,
    this.liftedAt,
    this.deliveredAt,
    this.timeline = const [],
  });

  final String id;
  final String customerId;
  final String customerName;
  final ProductType product;
  final int quantity;
  final Depot depot;
  final DeliveryPoint destination;
  final double distanceKm;
  final DateTime createdAt;
  final OrderStatus status;

  /// Gross fare the customer pays for haulage (platform fee comes out of it).
  final double driverFare;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final TruckClass? truckClass;
  final String? truckPlate;
  final String? listingId;
  final String? offtakerId;
  final String? offtakerName;
  final double? unitPrice;
  final Atl? atl;
  final DateTime? liftedAt;
  final DateTime? deliveredAt;
  final List<OrderEvent> timeline;

  String get reference => 'ONT-${id.substring(0, 6).toUpperCase()}';

  double get productCost => (unitPrice ?? 0) * quantity;

  bool get driverEscrowFunded => status.stepIndex >= OrderStatus.driverFunded.stepIndex;
  bool get productEscrowFunded => status.stepIndex >= OrderStatus.productFunded.stepIndex;

  DateTime? timeOf(OrderStatus s) {
    for (final e in timeline) {
      if (e.status == s) return e.at;
    }
    return null;
  }

  Order copyWith({
    OrderStatus? status,
    String? driverId,
    String? driverName,
    String? driverPhone,
    TruckClass? truckClass,
    String? truckPlate,
    double? driverFare,
    String? listingId,
    String? offtakerId,
    String? offtakerName,
    double? unitPrice,
    Atl? atl,
    DateTime? liftedAt,
    DateTime? deliveredAt,
    List<OrderEvent>? timeline,
  }) {
    return Order(
      id: id,
      customerId: customerId,
      customerName: customerName,
      product: product,
      quantity: quantity,
      depot: depot,
      destination: destination,
      distanceKm: distanceKm,
      createdAt: createdAt,
      status: status ?? this.status,
      driverFare: driverFare ?? this.driverFare,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      truckClass: truckClass ?? this.truckClass,
      truckPlate: truckPlate ?? this.truckPlate,
      listingId: listingId ?? this.listingId,
      offtakerId: offtakerId ?? this.offtakerId,
      offtakerName: offtakerName ?? this.offtakerName,
      unitPrice: unitPrice ?? this.unitPrice,
      atl: atl ?? this.atl,
      liftedAt: liftedAt ?? this.liftedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      timeline: timeline ?? this.timeline,
    );
  }

  Order advance(OrderStatus next, String note) => copyWith(
        status: next,
        timeline: [...timeline, OrderEvent(status: next, at: DateTime.now(), note: note)],
      );
}
