import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/listing.dart';
import '../../core/models/order.dart';
import '../../core/services/pricing.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../core/models/product.dart';

/// After the driver is locked in, the customer picks who sells the product.
class SelectSellerScreen extends ConsumerWidget {
  const SelectSellerScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(listingsProvider);
    final order = ref.watch(ordersProvider).where((o) => o.id == orderId).firstOrNull;
    if (order == null) return const Scaffold(body: Center(child: Text('Order not found')));
    final listings = ref.read(listingsProvider.notifier).visibleFor(depot: order.depot, product: order.product, quantity: order.quantity);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a seller')),
      body: listings.isEmpty
          ? EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No verified stock at ${order.depot.name}',
              body: 'No seller currently has a valid proof of ${order.product.shortLabel} for ${qty(order.quantity, order.product.unit)} at this depot. Check back shortly or cancel and choose another depot.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Sellers holding ${order.product.shortLabel} at ${order.depot.name} with proof of product on file. Cheapest first.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final l in listings) _ListingCard(order: order, listing: l),
              ],
            ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.order, required this.listing});

  final Order order;
  final ProductListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final total = listing.pricePerUnit * order.quantity;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(listing.offtakerName, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 16, color: Colors.green),
                      ]),
                      Text('Proof ${listing.proofReference} · valid to ${dateOnly(listing.proofExpiresAt)}', style: t.bodySmall),
                      Text('${qty(listing.availableQuantity, order.product.unit)} available', style: t.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${nairaExact(listing.pricePerUnit)}/${order.product.unit}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(naira(total), style: t.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _confirm(context, ref, total),
              child: Text('Pay ${naira(total)} into escrow'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, double total) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay product into escrow'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow('Seller', listing.offtakerName),
            InfoRow('Quantity', qty(order.quantity, order.product.unit)),
            InfoRow('Unit price', '${nairaExact(listing.pricePerUnit)}/${order.product.unit}'),
            InfoRow('Total held', naira(total), emphasize: true),
            const SizedBox(height: 8),
            Text(
              'Ontero holds this until the depot loads your truck. The seller then receives ${naira(Pricing.netOfFee(total))} after the 5% platform fee.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pay now')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(ordersProvider.notifier).fundProductEscrow(order.id, listing);
    context.pop();
  }
}
