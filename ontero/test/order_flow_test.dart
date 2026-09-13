import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ontero/core/data/seed_data.dart';
import 'package:ontero/core/models/ledger.dart';
import 'package:ontero/core/models/order.dart';
import 'package:ontero/core/models/product.dart';
import 'package:ontero/core/services/pricing.dart';
import 'package:ontero/state/providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Order start() {
    final customer = container.read(sessionProvider.notifier).signIn(phone: '+2348000000000', name: 'Test Buyer');
    final depot = SeedData.depotById('dep-dangote');
    final driver = container.read(usersProvider.notifier).matchingDrivers(product: ProductType.pms, quantity: 33000, depot: depot).first;
    return container.read(ordersProvider.notifier).create(
          customer: customer,
          product: ProductType.pms,
          quantity: 33000,
          depot: depot,
          destination: const DeliveryPoint(label: 'Ikeja', address: 'Ikeja, Lagos', location: LatLng(6.6018, 3.3515)),
          driver: driver,
        );
  }

  test('matching drivers respects product and capacity', () {
    final depot = SeedData.depotById('dep-navgas');
    final lpg = container.read(usersProvider.notifier).matchingDrivers(product: ProductType.lpg, quantity: 15000, depot: depot);
    expect(lpg.map((u) => u.id), ['drv-yusuf']);
    final tooBig = container.read(usersProvider.notifier).matchingDrivers(product: ProductType.pms, quantity: 70000, depot: depot);
    expect(tooBig, isEmpty);
  });

  test('full lifecycle releases escrow in the right order and takes 5%', () {
    final orders = container.read(ordersProvider.notifier);
    final ledger = container.read(ledgerProvider.notifier);
    var o = start();
    expect(o.status, OrderStatus.awaitingDriver);

    // Nothing can be funded before the driver accepts.
    orders.fundDriverEscrow(o.id);
    expect(orders.byId(o.id)!.status, OrderStatus.awaitingDriver);

    orders.driverAccept(o.id);
    orders.fundDriverEscrow(o.id);
    o = orders.byId(o.id)!;
    expect(o.status, OrderStatus.driverFunded);
    expect(ledger.heldInEscrow(), o.driverFare);

    final listing = container.read(listingsProvider.notifier).visibleFor(depot: o.depot, product: o.product, quantity: o.quantity).first;
    final stockBefore = listing.availableQuantity;
    orders.fundProductEscrow(o.id, listing);
    o = orders.byId(o.id)!;
    expect(o.status, OrderStatus.productFunded);
    expect(o.productCost, listing.pricePerUnit * 33000);
    expect(ledger.heldInEscrow(), o.driverFare + o.productCost);
    expect(container.read(listingsProvider.notifier).byId(listing.id)!.availableQuantity, stockBefore - 33000);

    // Driver cannot confirm a lift without an ATL.
    orders.confirmLift(o.id);
    expect(orders.byId(o.id)!.status, OrderStatus.productFunded);

    orders.issueAtl(o.id, issuedBy: listing.offtakerName);
    o = orders.byId(o.id)!;
    expect(o.atl, isNotNull);
    expect(o.atl!.truckPlate, o.truckPlate);

    orders.confirmLift(o.id);
    o = orders.byId(o.id)!;
    expect(o.status, OrderStatus.lifted);
    expect(ledger.balanceFor(o.driverId!), closeTo(Pricing.netOfFee(o.driverFare * 0.5), 0.01));
    expect(ledger.balanceFor(o.offtakerId!), closeTo(Pricing.netOfFee(o.productCost), 0.01));

    orders.confirmDelivery(o.id);
    orders.confirmReceipt(o.id);
    o = orders.byId(o.id)!;
    expect(o.status, OrderStatus.completed);
    expect(ledger.balanceFor(o.driverId!), closeTo(Pricing.netOfFee(o.driverFare), 0.01));

    final fees = container.read(ledgerProvider).where((e) => e.kind == LedgerKind.fee).fold<double>(0, (s, e) => s + e.amount);
    expect(fees, closeTo(Pricing.platformFee(o.driverFare + o.productCost), 0.01));
    expect(ledger.heldInEscrow(), closeTo(0, 0.01));
  });

  test('cancelling after funding refunds the customer and restores stock', () {
    final orders = container.read(ordersProvider.notifier);
    final ledger = container.read(ledgerProvider.notifier);
    var o = start();
    orders.driverAccept(o.id);
    orders.fundDriverEscrow(o.id);
    final listing = container.read(listingsProvider.notifier).visibleFor(depot: o.depot, product: o.product, quantity: o.quantity).first;
    orders.fundProductEscrow(o.id, listing);
    o = orders.byId(o.id)!;

    orders.cancel(o.id, 'changed plans');
    o = orders.byId(o.id)!;
    expect(o.status, OrderStatus.cancelled);
    expect(ledger.balanceFor(o.customerId), closeTo(0, 0.01));
    expect(ledger.heldInEscrow(), closeTo(0, 0.01));
    expect(container.read(listingsProvider.notifier).byId(listing.id)!.availableQuantity, listing.availableQuantity);
  });

  test('cancel is refused once product has been lifted', () {
    final orders = container.read(ordersProvider.notifier);
    var o = start();
    orders.driverAccept(o.id);
    orders.fundDriverEscrow(o.id);
    final listing = container.read(listingsProvider.notifier).visibleFor(depot: o.depot, product: o.product, quantity: o.quantity).first;
    orders.fundProductEscrow(o.id, listing);
    orders.issueAtl(o.id, issuedBy: 'x');
    orders.confirmLift(o.id);
    orders.cancel(o.id, 'too late');
    expect(orders.byId(o.id)!.status, OrderStatus.lifted);
  });
}
