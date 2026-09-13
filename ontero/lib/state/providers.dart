import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../core/data/seed_data.dart';
import '../core/models/depot.dart';
import '../core/models/ledger.dart';
import '../core/models/listing.dart';
import '../core/models/order.dart';
import '../core/models/product.dart';
import '../core/models/truck.dart';
import '../core/models/user.dart';
import '../core/services/pricing.dart';

const _uuid = Uuid();

final depotsProvider = Provider<List<Depot>>((ref) => SeedData.depots);

// ---------------------------------------------------------------------------
// Users directory (seeded counterparties + everyone who registers on device)
// ---------------------------------------------------------------------------

class UsersNotifier extends Notifier<List<AppUser>> {
  @override
  List<AppUser> build() => [...SeedData.drivers, ...SeedData.offtakers];

  AppUser? byId(String id) {
    for (final u in state) {
      if (u.id == id) return u;
    }
    return null;
  }

  AppUser? byPhone(String phone) {
    for (final u in state) {
      if (u.phone == phone) return u;
    }
    return null;
  }

  void upsert(AppUser user) {
    final idx = state.indexWhere((u) => u.id == user.id);
    if (idx == -1) {
      state = [...state, user];
    } else {
      final copy = [...state];
      copy[idx] = user;
      state = copy;
    }
  }

  /// Verified drivers whose truck can carry [product] in [quantity], nearest to [depot] first.
  List<AppUser> matchingDrivers({
    required ProductType product,
    required int quantity,
    required Depot depot,
    String? excludeUserId,
  }) {
    final list = state.where((u) {
      final d = u.driver;
      return d != null && u.id != excludeUserId && d.canTakeJobs && d.canCarry(product, quantity);
    }).toList();
    list.sort((a, b) => Pricing.straightLineKm(a.driver!.location, depot.location)
        .compareTo(Pricing.straightLineKm(b.driver!.location, depot.location)));
    return list;
  }
}

final usersProvider = NotifierProvider<UsersNotifier, List<AppUser>>(UsersNotifier.new);

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

class SessionNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  /// Phone + OTP sign in. Unknown numbers get a fresh customer account.
  AppUser signIn({required String phone, required String name}) {
    final users = ref.read(usersProvider.notifier);
    final existing = users.byPhone(phone);
    final user = existing ??
        AppUser(id: 'usr-${_uuid.v4()}', name: name, phone: phone, activeRole: AppRole.customer);
    users.upsert(user);
    state = user;
    return user;
  }

  void signOut() => state = null;

  void update(AppUser Function(AppUser) mutate) {
    final current = state;
    if (current == null) return;
    final next = mutate(current);
    ref.read(usersProvider.notifier).upsert(next);
    state = next;
  }

  void switchRole(AppRole role) => update((u) => u.copyWith(activeRole: role));

  void setBankAccount(BankAccount account) => update((u) => u.copyWith(bankAccount: account));

  // ---- Driver gate -------------------------------------------------------

  void submitDriverApplication(DriverProfile profile) {
    update((u) => u.copyWith(driver: profile.copyWith(status: VerificationStatus.pending)));
    // Placeholder for the compliance review queue: auto-approve shortly after submission.
    Timer(const Duration(seconds: 6), () {
      final current = state;
      final d = current?.driver;
      if (current == null || d == null || d.status != VerificationStatus.pending) return;
      update((u) => u.copyWith(
            driver: d.copyWith(status: VerificationStatus.approved, verifiedAt: DateTime.now()),
          ));
    });
  }

  /// Monthly re-check: fresh liveness selfie and truck photo.
  void completeDriverRecheck({required CapturedPhoto selfie, required CapturedPhoto truckPhoto}) {
    update((u) {
      final d = u.driver!;
      return u.copyWith(
        driver: d.copyWith(
          livenessPassedAt: DateTime.now(),
          verifiedAt: DateTime.now(),
          status: VerificationStatus.approved,
          truck: d.truck.copyWith(photos: [...d.truck.photos, truckPhoto]),
        ),
      );
    });
  }

  void setDriverAvailability(bool available) =>
      update((u) => u.copyWith(driver: u.driver?.copyWith(available: available)));

  // ---- Offtaker gate -----------------------------------------------------

  void submitOfftakerApplication(OfftakerProfile profile) {
    update((u) => u.copyWith(offtaker: profile.copyWith(status: VerificationStatus.pending)));
    Timer(const Duration(seconds: 6), () {
      final current = state;
      final o = current?.offtaker;
      if (current == null || o == null || o.status != VerificationStatus.pending) return;
      update((u) => u.copyWith(
            offtaker: o.copyWith(status: VerificationStatus.approved, verifiedAt: DateTime.now()),
          ));
    });
  }

  void addProofOfProduct(ProofOfProduct proof) =>
      update((u) => u.copyWith(offtaker: u.offtaker!.copyWith(proofs: [...u.offtaker!.proofs, proof])));
}

final sessionProvider = NotifierProvider<SessionNotifier, AppUser?>(SessionNotifier.new);

// ---------------------------------------------------------------------------
// Listings
// ---------------------------------------------------------------------------

class ListingsNotifier extends Notifier<List<ProductListing>> {
  @override
  List<ProductListing> build() => SeedData.listings();

  ProductListing? byId(String id) {
    for (final l in state) {
      if (l.id == id) return l;
    }
    return null;
  }

  List<ProductListing> visibleFor({required Depot depot, required ProductType product, required int quantity}) {
    final list = state.where((l) => l.isVisible && l.depotId == depot.id && l.product == product && l.canFill(quantity)).toList();
    list.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    return list;
  }

  List<ProductListing> forOfftaker(String offtakerId) => state.where((l) => l.offtakerId == offtakerId).toList();

  ProductListing create({
    required AppUser offtaker,
    required ProofOfProduct proof,
    required double pricePerUnit,
    required int availableQuantity,
    required int minQuantity,
  }) {
    final listing = ProductListing(
      id: 'lst-${_uuid.v4()}',
      offtakerId: offtaker.id,
      offtakerName: offtaker.offtaker!.companyName,
      depotId: proof.depotId,
      product: proof.product,
      pricePerUnit: pricePerUnit,
      availableQuantity: availableQuantity,
      minQuantity: minQuantity,
      proofId: proof.id,
      proofReference: proof.reference,
      proofExpiresAt: proof.expiresAt,
      createdAt: DateTime.now(),
    );
    state = [listing, ...state];
    return listing;
  }

  void setActive(String id, bool active) => _mutate(id, (l) => l.copyWith(active: active));

  void reserve(String id, int quantity) =>
      _mutate(id, (l) => l.copyWith(availableQuantity: (l.availableQuantity - quantity).clamp(0, 1 << 31)));

  void _mutate(String id, ProductListing Function(ProductListing) f) {
    state = [for (final l in state) l.id == id ? f(l) : l];
  }
}

final listingsProvider = NotifierProvider<ListingsNotifier, List<ProductListing>>(ListingsNotifier.new);

// ---------------------------------------------------------------------------
// Escrow ledger
// ---------------------------------------------------------------------------

class LedgerNotifier extends Notifier<List<LedgerEntry>> {
  @override
  List<LedgerEntry> build() => [];

  void add({
    required Order order,
    required LedgerKind kind,
    required LedgerParty party,
    required String partyId,
    required double amount,
    required String note,
  }) {
    state = [
      LedgerEntry(
        id: _uuid.v4(),
        orderId: order.id,
        orderReference: order.reference,
        kind: kind,
        party: party,
        partyId: partyId,
        amount: amount,
        note: note,
        at: DateTime.now(),
      ),
      ...state,
    ];
  }

  List<LedgerEntry> forUser(String userId) => state.where((e) => e.partyId == userId).toList();

  double balanceFor(String userId) => forUser(userId).fold(0, (sum, e) => sum + e.signedForParty);

  /// Money paid in by customers that has not yet been released or refunded.
  double heldInEscrow() {
    var held = 0.0;
    for (final e in state) {
      switch (e.kind) {
        case LedgerKind.escrowIn:
          held += e.amount;
        case LedgerKind.release || LedgerKind.fee || LedgerKind.refund:
          held -= e.amount;
      }
    }
    return held;
  }
}

final ledgerProvider = NotifierProvider<LedgerNotifier, List<LedgerEntry>>(LedgerNotifier.new);

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() => [];

  Order? byId(String id) {
    for (final o in state) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<Order> forCustomer(String id) => state.where((o) => o.customerId == id).toList();
  List<Order> forDriver(String id) => state.where((o) => o.driverId == id).toList();
  List<Order> forOfftaker(String id) => state.where((o) => o.offtakerId == id).toList();

  /// Customer requests a specific driver for a product, depot and destination.
  Order create({
    required AppUser customer,
    required ProductType product,
    required int quantity,
    required Depot depot,
    required DeliveryPoint destination,
    required AppUser driver,
  }) {
    final km = Pricing.roadKm(depot.location, destination.location);
    final truck = driver.driver!.truck;
    final order = Order(
      id: _uuid.v4(),
      customerId: customer.id,
      customerName: customer.name,
      product: product,
      quantity: quantity,
      depot: depot,
      destination: destination,
      distanceKm: km,
      createdAt: DateTime.now(),
      status: OrderStatus.awaitingDriver,
      driverFare: Pricing.driverFare(truck.truckClass, km),
      driverId: driver.id,
      driverName: driver.name,
      driverPhone: driver.phone,
      truckClass: truck.truckClass,
      truckPlate: truck.plate,
      timeline: [
        OrderEvent(status: OrderStatus.awaitingDriver, at: DateTime.now(), note: 'Request sent to ${driver.name}'),
      ],
    );
    state = [order, ...state];
    return order;
  }

  void driverAccept(String orderId) => _transition(
        orderId,
        from: OrderStatus.awaitingDriver,
        to: OrderStatus.driverAccepted,
        note: 'Driver accepted. Waiting for customer to fund escrow.',
      );

  void driverDecline(String orderId) => _transition(
        orderId,
        from: OrderStatus.awaitingDriver,
        to: OrderStatus.cancelled,
        note: 'Driver declined the request.',
      );

  /// Customer pays the driver fare into escrow. This locks the driver in.
  void fundDriverEscrow(String orderId) {
    final order = byId(orderId);
    if (order == null || order.status != OrderStatus.driverAccepted) return;
    ref.read(ledgerProvider.notifier).add(
          order: order,
          kind: LedgerKind.escrowIn,
          party: LedgerParty.customer,
          partyId: order.customerId,
          amount: order.driverFare,
          note: 'Driver fare held in escrow',
        );
    _transition(orderId, from: OrderStatus.driverAccepted, to: OrderStatus.driverFunded,
        note: 'Driver fare of ${order.driverFare.toStringAsFixed(0)} held in escrow. Choose a seller.');
  }

  /// Customer picks a listing and pays the product cost into escrow.
  void fundProductEscrow(String orderId, ProductListing listing) {
    final order = byId(orderId);
    if (order == null || order.status != OrderStatus.driverFunded) return;
    if (!listing.isVisible || !listing.canFill(order.quantity)) return;
    final updated = order.copyWith(
      listingId: listing.id,
      offtakerId: listing.offtakerId,
      offtakerName: listing.offtakerName,
      unitPrice: listing.pricePerUnit,
    );
    _replace(updated);
    ref.read(listingsProvider.notifier).reserve(listing.id, order.quantity);
    ref.read(ledgerProvider.notifier).add(
          order: updated,
          kind: LedgerKind.escrowIn,
          party: LedgerParty.customer,
          partyId: order.customerId,
          amount: updated.productCost,
          note: 'Product cost held in escrow',
        );
    _transition(orderId, from: OrderStatus.driverFunded, to: OrderStatus.productFunded,
        note: 'Product paid into escrow. ${listing.offtakerName} to raise ATL on ${order.truckPlate}.');
  }

  /// Offtaker raises the Authority To Lift naming the driver and truck.
  void issueAtl(String orderId, {required String issuedBy}) {
    final order = byId(orderId);
    if (order == null || order.status != OrderStatus.productFunded) return;
    final now = DateTime.now();
    final atl = Atl(
      number: 'ATL-${now.year}${now.month.toString().padLeft(2, '0')}-${order.id.substring(0, 5).toUpperCase()}',
      issuedAt: now,
      issuedBy: issuedBy,
      depotId: order.depot.id,
      product: order.product,
      quantity: order.quantity,
      truckPlate: order.truckPlate ?? '',
      driverName: order.driverName ?? '',
      validUntil: now.add(const Duration(days: 3)),
    );
    _replace(order.copyWith(atl: atl));
    _transition(orderId, from: OrderStatus.productFunded, to: OrderStatus.atlIssued,
        note: 'ATL ${atl.number} issued to ${order.driverName}. Driver to proceed to ${order.depot.name}.');
  }

  /// Driver confirms the truck was loaded. Releases 50% of the fare to the
  /// driver and the full product payment to the offtaker, less platform fees.
  void confirmLift(String orderId) {
    final order = byId(orderId);
    if (order == null || order.status != OrderStatus.atlIssued) return;
    final ledger = ref.read(ledgerProvider.notifier);
    final driverGross = order.driverFare * Pricing.driverLiftReleaseShare;
    _release(ledger, order, LedgerParty.driver, order.driverId!, driverGross, 'Loading confirmed: 50% of fare');
    _release(ledger, order, LedgerParty.offtaker, order.offtakerId!, order.productCost, 'Product lifted: full payment');
    _replace(order.copyWith(liftedAt: DateTime.now()));
    _transition(orderId, from: OrderStatus.atlIssued, to: OrderStatus.lifted,
        note: 'Loaded at ${order.depot.name}. Seller paid, driver received 50%. Truck en route.');
    _bumpOfftakerStats(order.offtakerId!);
  }

  void confirmDelivery(String orderId) {
    final order = byId(orderId);
    if (order == null || order.status != OrderStatus.lifted) return;
    _replace(order.copyWith(deliveredAt: DateTime.now()));
    _transition(orderId, from: OrderStatus.lifted, to: OrderStatus.delivered,
        note: 'Driver reports delivery at ${order.destination.label}. Customer to confirm receipt.');
  }

  /// Customer confirms receipt. Releases the remaining fare to the driver.
  void confirmReceipt(String orderId) {
    final order = byId(orderId);
    if (order == null || order.status != OrderStatus.delivered) return;
    final ledger = ref.read(ledgerProvider.notifier);
    final rest = order.driverFare * (1 - Pricing.driverLiftReleaseShare);
    _release(ledger, order, LedgerParty.driver, order.driverId!, rest, 'Delivery confirmed: balance of fare');
    _transition(orderId, from: OrderStatus.delivered, to: OrderStatus.completed, note: 'Order completed. Driver paid in full.');
    _bumpDriverStats(order.driverId!);
  }

  /// Cancel before anything is lifted. Escrowed funds go back to the customer.
  void cancel(String orderId, String reason) {
    final order = byId(orderId);
    if (order == null || !order.status.isOpen || order.status.stepIndex >= OrderStatus.lifted.stepIndex) return;
    final ledger = ref.read(ledgerProvider.notifier);
    var refund = 0.0;
    if (order.driverEscrowFunded) refund += order.driverFare;
    if (order.productEscrowFunded) refund += order.productCost;
    if (refund > 0) {
      ledger.add(order: order, kind: LedgerKind.refund, party: LedgerParty.customer, partyId: order.customerId, amount: refund, note: 'Escrow refunded: $reason');
    }
    if (order.listingId != null) {
      ref.read(listingsProvider.notifier).reserve(order.listingId!, -order.quantity);
    }
    _transition(orderId, from: order.status, to: OrderStatus.cancelled, note: 'Cancelled: $reason');
  }

  // ---- helpers -----------------------------------------------------------

  void _release(LedgerNotifier ledger, Order order, LedgerParty party, String partyId, double gross, String note) {
    final fee = Pricing.platformFee(gross);
    ledger.add(order: order, kind: LedgerKind.release, party: party, partyId: partyId, amount: gross - fee, note: note);
    ledger.add(order: order, kind: LedgerKind.fee, party: LedgerParty.platform, partyId: 'ontero', amount: fee, note: 'Platform fee (5%) on ${party.name} payout');
  }

  void _transition(String orderId, {required OrderStatus from, required OrderStatus to, required String note}) {
    final order = byId(orderId);
    if (order == null || order.status != from) return;
    _replace(order.advance(to, note));
  }

  void _replace(Order updated) {
    state = [for (final o in state) o.id == updated.id ? updated : o];
  }

  void _bumpDriverStats(String driverId) {
    final users = ref.read(usersProvider.notifier);
    final u = users.byId(driverId);
    if (u?.driver == null) return;
    final d = u!.driver!;
    final next = u.copyWith(driver: d.copyWith(tripsCompleted: d.tripsCompleted + 1));
    users.upsert(next);
    if (ref.read(sessionProvider)?.id == driverId) ref.read(sessionProvider.notifier).update((_) => next);
  }

  void _bumpOfftakerStats(String offtakerId) {
    final users = ref.read(usersProvider.notifier);
    final u = users.byId(offtakerId);
    if (u?.offtaker == null) return;
    final o = u!.offtaker!;
    final next = u.copyWith(offtaker: o.copyWith(ordersFulfilled: o.ordersFulfilled + 1));
    users.upsert(next);
    if (ref.read(sessionProvider)?.id == offtakerId) ref.read(sessionProvider.notifier).update((_) => next);
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

// ---------------------------------------------------------------------------
// Demo simulator: plays the seeded drivers and offtakers so a single device
// can walk an order from request to completion. Replace with server push
// notifications once the backend exists.
// ---------------------------------------------------------------------------

class DemoSimulator {
  DemoSimulator(this.ref);

  final Ref ref;
  final _scheduled = <String>{};

  void onOrdersChanged(List<Order> orders) {
    final users = ref.read(usersProvider.notifier);
    for (final o in orders) {
      final key = '${o.id}:${o.status.name}';
      if (_scheduled.contains(key)) continue;
      final driverSeeded = o.driverId != null && (users.byId(o.driverId!)?.isSeeded ?? false);
      final offtakerSeeded = o.offtakerId != null && (users.byId(o.offtakerId!)?.isSeeded ?? false);
      final notifier = ref.read(ordersProvider.notifier);
      switch (o.status) {
        case OrderStatus.awaitingDriver when driverSeeded:
          _later(key, 5, () => notifier.driverAccept(o.id));
        case OrderStatus.productFunded when offtakerSeeded:
          _later(key, 8, () => notifier.issueAtl(o.id, issuedBy: o.offtakerName ?? 'Seller'));
        case OrderStatus.atlIssued when driverSeeded:
          _later(key, 12, () => notifier.confirmLift(o.id));
        case OrderStatus.lifted when driverSeeded:
          _later(key, 15, () => notifier.confirmDelivery(o.id));
        default:
          break;
      }
    }
  }

  void _later(String key, int seconds, void Function() action) {
    _scheduled.add(key);
    Timer(Duration(seconds: seconds), action);
  }
}

final demoSimulatorProvider = Provider<DemoSimulator>((ref) {
  final sim = DemoSimulator(ref);
  ref.listen<List<Order>>(ordersProvider, (_, next) => sim.onOrdersChanged(next));
  return sim;
});

// ---------------------------------------------------------------------------
// Convenience selectors
// ---------------------------------------------------------------------------

final myOrdersProvider = Provider<List<Order>>((ref) {
  final me = ref.watch(sessionProvider);
  final orders = ref.watch(ordersProvider);
  if (me == null) return const [];
  return switch (me.activeRole) {
    AppRole.customer => orders.where((o) => o.customerId == me.id).toList(),
    AppRole.driver => orders.where((o) => o.driverId == me.id).toList(),
    AppRole.offtaker => orders.where((o) => o.offtakerId == me.id).toList(),
  };
});

final myBalanceProvider = Provider<double>((ref) {
  final me = ref.watch(sessionProvider);
  ref.watch(ledgerProvider);
  if (me == null) return 0;
  return ref.read(ledgerProvider.notifier).balanceFor(me.id);
});

/// Rough current position for the signed-in driver (Lagos by default).
final defaultMapCenterProvider = Provider<LatLng>((_) => const LatLng(6.5244, 3.3792));
