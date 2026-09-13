import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/seed_data.dart';
import '../../core/models/order.dart';
import '../../core/models/user.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../customer/customer_home.dart';
import '../shell/home_shell.dart';
import '../../core/models/product.dart';

class OfftakerHome extends ConsumerWidget {
  const OfftakerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider)!;
    final o = user.offtaker;
    if (o == null) {
      return Scaffold(
        appBar: const RoleAppBar(title: 'Seller'),
        body: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Register your company',
          body: 'Sellers need a CAC registration, an NMDPRA licence and a proof of product for every depot they list at. You are paid from escrow the moment the truck is loaded.',
          action: FilledButton(onPressed: () => context.push('/offtaker/onboarding'), child: const Text('Start registration')),
        ),
      );
    }

    ref.watch(listingsProvider);
    final listings = ref.read(listingsProvider.notifier).forOfftaker(user.id);
    final orders = ref.watch(myOrdersProvider);
    final toIssue = orders.where((s) => s.status == OrderStatus.productFunded).toList();
    final inFlight = orders.where((s) => s.status.isOpen && s.status != OrderStatus.productFunded).toList();
    final verified = o.isVerified;

    return Scaffold(
      appBar: const RoleAppBar(title: 'Seller'),
      floatingActionButton: verified
          ? FloatingActionButton.extended(onPressed: () => context.push('/offtaker/listings/new'), icon: const Icon(Icons.add), label: const Text('List product'))
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(o.companyName),
              subtitle: Text('${o.validProofs.length} valid proofs · ${o.ordersFulfilled} orders fulfilled'),
              trailing: VerificationBadge(o.status),
              onTap: () => context.push('/offtaker/onboarding'),
            ),
          ),
          if (o.status == VerificationStatus.pending)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Verification in progress. You can list product once approved.')),
          SectionTitle('Awaiting your ATL (${toIssue.length})'),
          if (toIssue.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No paid orders waiting. When a buyer pays for your product, raise the ATL here.')))
          else
            for (final s in toIssue) _AtlCard(s),
          SectionTitle('In progress (${inFlight.length})'),
          if (inFlight.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nothing lifting right now.')))
          else
            for (final s in inFlight) OrderCard(s, subtitleOverride: '${s.driverName} · ${s.truckPlate} · ${s.depot.name}'),
          SectionTitle('Your listings (${listings.length})'),
          if (listings.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No listings yet.')))
          else
            for (final l in listings)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: ProductIcon(l.product, size: 36),
                  title: Text('${l.product.shortLabel} at ${SeedData.depotById(l.depotId).name}'),
                  subtitle: Text('${nairaExact(l.pricePerUnit)}/${l.product.unit} · ${qty(l.availableQuantity, l.product.unit)} left · proof to ${dateOnly(l.proofExpiresAt)}'),
                  trailing: Switch(value: l.active && l.proofValid, onChanged: l.proofValid ? (v) => ref.read(listingsProvider.notifier).setActive(l.id, v) : null),
                ),
              ),
        ],
      ),
    );
  }
}

class _AtlCard extends ConsumerWidget {
  const _AtlCard(this.o);

  final Order o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.read(sessionProvider)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${qty(o.quantity, o.product.unit)} ${o.product.shortLabel} · ${naira(o.productCost)} in escrow', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Truck ${o.truckPlate} (${o.driverName}) will load at ${o.depot.name}. Raise the ATL so the depot releases product to this truck.'),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: () => ref.read(ordersProvider.notifier).issueAtl(o.id, issuedBy: me.offtaker!.companyName),
              child: const Text('Issue authority to lift'),
            ),
          ],
        ),
      ),
    );
  }
}
