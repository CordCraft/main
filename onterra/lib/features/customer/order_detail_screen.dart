import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/order.dart';
import '../../core/models/user.dart';
import '../../core/services/pricing.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../core/models/product.dart';
import '../../core/models/truck.dart';

/// Tracking page shared by all three roles. The action card at the top shows
/// whatever the signed-in party has to do next for this order.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(ordersProvider).where((o) => o.id == orderId).firstOrNull;
    final me = ref.watch(sessionProvider)!;
    if (order == null) {
      return const Scaffold(body: Center(child: Text('Order not found')));
    }
    final isCustomer = order.customerId == me.id;
    final isDriver = order.driverId == me.id;
    final isOfftaker = order.offtakerId == me.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(order.reference),
        actions: [
          if (isCustomer && order.status.isOpen && order.status.stepIndex < OrderStatus.lifted.stepIndex)
            IconButton(
              tooltip: 'Cancel order',
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _cancel(context, ref, order),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              ProductIcon(order.product, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${qty(order.quantity, order.product.unit)} ${order.product.label}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('${order.depot.name} to ${order.destination.label}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              StatusChip(order.status),
            ],
          ),
          const SizedBox(height: 14),
          _ActionCard(order: order, isCustomer: isCustomer, isDriver: isDriver, isOfftaker: isOfftaker),
          const SizedBox(height: 14),
          RouteMap(
            from: order.depot.location,
            to: order.destination.location,
            truckAt: order.status == OrderStatus.lifted ? _midpoint(order) : null,
          ),
          const SectionTitle('Escrow'),
          _EscrowCard(order: order, role: me.activeRole),
          const SectionTitle('Parties'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(order.customerName),
                  subtitle: const Text('Customer'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(order.driverName ?? 'Not assigned'),
                  subtitle: Text(order.truckClass == null ? 'Driver' : '${order.truckClass!.label} · ${order.truckPlate}'),
                  trailing: order.driverPhone != null && order.driverEscrowFunded ? Text(order.driverPhone!) : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(order.offtakerName ?? 'Not chosen yet'),
                  subtitle: Text(order.unitPrice == null ? 'Seller' : 'Seller · ${nairaExact(order.unitPrice!)}/${order.product.unit}'),
                ),
              ],
            ),
          ),
          if (order.atl != null) ...[
            const SectionTitle('Authority to lift'),
            _AtlCard(order.atl!),
          ],
          const SectionTitle('Timeline'),
          _Timeline(order),
        ],
      ),
    );
  }

  static LatLng _midpoint(Order o) {
    final a = o.depot.location;
    final b = o.destination.location;
    return LatLng(a.latitude + (b.latitude - a.latitude) * 0.45, a.longitude + (b.longitude - a.longitude) * 0.45);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Order order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(order.driverEscrowFunded
            ? 'Everything you have paid into escrow is refunded in full. The driver and seller are released.'
            : 'The request is withdrawn. Nothing has been charged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel order')),
        ],
      ),
    );
    if (ok == true) ref.read(ordersProvider.notifier).cancel(order.id, 'Cancelled by customer');
  }
}

// ---------------------------------------------------------------------------

class _ActionCard extends ConsumerWidget {
  const _ActionCard({required this.order, required this.isCustomer, required this.isDriver, required this.isOfftaker});

  final Order order;
  final bool isCustomer;
  final bool isDriver;
  final bool isOfftaker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.read(ordersProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final me = ref.read(sessionProvider)!;

    (String, String, Widget?) content = switch (order.status) {
      OrderStatus.awaitingDriver when isDriver => (
          'Accept this job?',
          'Load ${qty(order.quantity, order.product.unit)} at ${order.depot.name} and deliver ${order.distanceKm.toStringAsFixed(0)} km to ${order.destination.address}. Fare ${naira(order.driverFare)}.',
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => orders.driverDecline(order.id), child: const Text('Decline'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: () => orders.driverAccept(order.id), child: const Text('Accept'))),
          ]),
        ),
      OrderStatus.awaitingDriver => ('Waiting for ${order.driverName}', 'Drivers usually answer within a few minutes. You are not charged until the driver accepts.', null),
      OrderStatus.driverAccepted when isCustomer => (
          'Lock in ${order.driverName}',
          'Pay the haulage fare of ${naira(order.driverFare)} into Onterra escrow. The driver receives half when the truck is loaded and the rest when you confirm delivery.',
          FilledButton(onPressed: () => _payDriver(context, ref), child: Text('Pay ${naira(order.driverFare)} into escrow')),
        ),
      OrderStatus.driverAccepted => ('Waiting for customer to fund escrow', 'You will be notified once the fare is secured.', null),
      OrderStatus.driverFunded when isCustomer => (
          'Choose who sells the product',
          'Your driver is secured. Pick a verified seller with proof of ${order.product.shortLabel} at ${order.depot.name} and pay the product into escrow.',
          FilledButton(onPressed: () => context.push('/orders/${order.id}/seller'), child: const Text('See sellers')),
        ),
      OrderStatus.driverFunded => ('Customer is choosing a seller', 'Standby. The ATL will be raised on ${order.truckPlate} once product is paid.', null),
      OrderStatus.productFunded when isOfftaker => (
          'Raise the authority to lift',
          '${naira(order.productCost)} is in escrow for ${qty(order.quantity, order.product.unit)}. Issue the ATL for truck ${order.truckPlate} (${order.driverName}).',
          FilledButton(onPressed: () => orders.issueAtl(order.id, issuedBy: me.offtaker?.companyName ?? me.name), child: const Text('Issue ATL')),
        ),
      OrderStatus.productFunded => ('Waiting for ${order.offtakerName} to issue the ATL', 'The seller registers your truck with the depot. This usually takes a few hours.', null),
      OrderStatus.atlIssued when isDriver => (
          'Go load at ${order.depot.name}',
          'Present ATL ${order.atl!.number} at the gantry. Confirm here once the depot has loaded the truck. Half your fare is released immediately.',
          FilledButton(onPressed: () => orders.confirmLift(order.id), child: const Text('Confirm truck loaded')),
        ),
      OrderStatus.atlIssued => ('ATL issued, truck heading to the depot', 'Seller and driver are paid from escrow the moment the depot confirms loading.', null),
      OrderStatus.lifted when isDriver => (
          'Deliver to ${order.destination.address}',
          'Confirm delivery when the product is discharged. The customer then releases the balance of your fare.',
          FilledButton(onPressed: () => orders.confirmDelivery(order.id), child: const Text('Confirm delivered')),
        ),
      OrderStatus.lifted => ('Product on the road', 'Loaded ${order.liftedAt == null ? '' : whenShort(order.liftedAt!)}. The seller has been paid and the driver has received half the fare.', null),
      OrderStatus.delivered when isCustomer => (
          'Did the product arrive?',
          'Confirm receipt to release the remaining ${naira(order.driverFare * (1 - Pricing.driverLiftReleaseShare))} to ${order.driverName}.',
          FilledButton(onPressed: () => orders.confirmReceipt(order.id), child: const Text('Confirm received')),
        ),
      OrderStatus.delivered => ('Waiting for customer to confirm receipt', 'The balance of the fare is released once the customer confirms.', null),
      OrderStatus.completed => ('Completed', 'All escrow released. Thanks for using Onterra.', null),
      OrderStatus.cancelled => ('Cancelled', order.timeline.isEmpty ? '' : order.timeline.last.note, null),
    };

    return Card(
      color: content.$3 == null ? null : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.$1, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(content.$2),
            if (content.$3 != null) ...[const SizedBox(height: 14), content.$3!],
          ],
        ),
      ),
    );
  }

  Future<void> _payDriver(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay driver fare into escrow'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoRow('Driver', order.driverName ?? ''),
            InfoRow('Truck', '${order.truckClass?.label} · ${order.truckPlate}'),
            InfoRow('Distance', '${order.distanceKm.toStringAsFixed(0)} km by road'),
            InfoRow('Held in escrow', naira(order.driverFare), emphasize: true),
            const SizedBox(height: 8),
            Text('Card, transfer or bank hold via the payment gateway. Refunded in full if the order is cancelled before loading.', style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pay now')),
        ],
      ),
    );
    if (ok == true) ref.read(ordersProvider.notifier).fundDriverEscrow(order.id);
  }
}

// ---------------------------------------------------------------------------

class _EscrowCard extends StatelessWidget {
  const _EscrowCard({required this.order, required this.role});

  final Order order;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final fare = order.driverFare;
    final product = order.productCost;
    final feeDriver = Pricing.platformFee(fare);
    final feeProduct = Pricing.platformFee(product);
    final step = order.status.stepIndex;
    final fareState = switch (order.status) {
      OrderStatus.cancelled => order.driverEscrowFunded ? 'refunded' : 'not charged',
      OrderStatus.completed => 'released to driver',
      _ when step >= OrderStatus.lifted.stepIndex => '50% released, 50% in escrow',
      _ when order.driverEscrowFunded => 'in escrow',
      _ => 'not yet paid',
    };
    final productState = switch (order.status) {
      OrderStatus.cancelled => 'refunded',
      _ when step >= OrderStatus.lifted.stepIndex => 'released to seller',
      _ => 'in escrow',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            InfoRow('Haulage fare', '${naira(fare)} · $fareState'),
            InfoRow('Product cost', order.unitPrice == null ? 'Seller not chosen' : '${naira(product)} · $productState'),
            const Divider(),
            if (role == AppRole.driver) ...[
              InfoRow('Released on loading (50%)', naira(Pricing.netOfFee(fare * Pricing.driverLiftReleaseShare))),
              InfoRow('Released on delivery (50%)', naira(Pricing.netOfFee(fare * (1 - Pricing.driverLiftReleaseShare)))),
              InfoRow('Onterra fee (5%)', naira(feeDriver)),
            ] else if (role == AppRole.offtaker) ...[
              InfoRow('Released on loading', naira(Pricing.netOfFee(product))),
              InfoRow('Onterra fee (5%)', naira(feeProduct)),
            ] else ...[
              InfoRow('Total you pay', naira(fare + product), emphasize: true),
              InfoRow('Driver receives', naira(Pricing.netOfFee(fare))),
              InfoRow('Seller receives', naira(Pricing.netOfFee(product))),
              InfoRow('Onterra fee (5%)', naira(feeDriver + feeProduct)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AtlCard extends StatelessWidget {
  const _AtlCard(this.atl);

  final Atl atl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            InfoRow('ATL number', atl.number, emphasize: true),
            InfoRow('Issued by', atl.issuedBy),
            InfoRow('Issued', whenShort(atl.issuedAt)),
            InfoRow('Valid until', whenShort(atl.validUntil)),
            InfoRow('Truck', '${atl.truckPlate} · ${atl.driverName}'),
            InfoRow('Quantity', qty(atl.quantity, atl.product.unit)),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.order);

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = OrderStatusX.timeline;
    final current = order.status == OrderStatus.cancelled ? -1 : order.status.stepIndex;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              _TimelineRow(
                status: steps[i],
                done: i <= current,
                active: i == current,
                time: order.timeOf(steps[i]),
                note: order.timeline.where((e) => e.status == steps[i]).map((e) => e.note).lastOrNull,
                isLast: i == steps.length - 1,
              ),
            if (order.status == OrderStatus.cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.cancel, color: scheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(order.timeline.last.note, style: TextStyle(color: scheme.error))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.status, required this.done, required this.active, required this.time, required this.note, required this.isLast});

  final OrderStatus status;
  final bool done;
  final bool active;
  final DateTime? time;
  final String? note;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = done ? scheme.primary : scheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(done ? (active ? Icons.radio_button_checked : Icons.check_circle) : Icons.radio_button_off, size: 20, color: color),
              if (!isLast) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(status.label, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: done ? null : scheme.outline))),
                      if (time != null) Text(whenShort(time!), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  if (note != null) Text(note!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
