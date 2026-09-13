import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/order.dart';
import '../../core/models/user.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../customer/customer_home.dart';
import '../shell/home_shell.dart';
import '../../core/models/product.dart';

class DriverHome extends ConsumerWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider)!;
    final d = user.driver;
    if (d == null) return _Gate(user: user);

    final orders = ref.watch(myOrdersProvider);
    final requests = orders.where((o) => o.status == OrderStatus.awaitingDriver).toList();
    final active = orders.where((o) => o.status.isOpen && o.status != OrderStatus.awaitingDriver).toList();
    final done = orders.where((o) => !o.status.isOpen).toList();
    final status = d.effectiveStatus;

    return Scaffold(
      appBar: const RoleAppBar(title: 'Driver'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d.truck.summary, style: const TextStyle(fontWeight: FontWeight.w700))),
                      VerificationBadge(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (status == VerificationStatus.approved)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available for jobs'),
                      subtitle: Text('Next re-check ${dateOnly(d.nextRecheckDue!)}'),
                      value: d.available,
                      onChanged: (v) => ref.read(sessionProvider.notifier).setDriverAvailability(v),
                    )
                  else if (status == VerificationStatus.expired)
                    FilledButton.tonal(onPressed: () => context.push('/driver/recheck'), child: const Text('Complete monthly re-check to keep taking jobs'))
                  else if (status == VerificationStatus.pending)
                    const Text('Verification in progress. Requests will appear once approved.')
                  else
                    TextButton(onPressed: () => context.push('/driver/onboarding'), child: const Text('View application')),
                ],
              ),
            ),
          ),
          SectionTitle('New requests (${requests.length})'),
          if (requests.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No new requests. Customers near your depot will find you when you are available.')))
          else
            for (final o in requests) _RequestCard(o),
          SectionTitle('Active jobs (${active.length})'),
          if (active.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No jobs in progress.')))
          else
            for (final o in active) OrderCard(o, subtitleOverride: '${o.customerName} · ${o.depot.name} to ${o.destination.label}'),
          if (done.isNotEmpty) ...[
            const SectionTitle('Completed'),
            for (final o in done) OrderCard(o),
          ],
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard(this.o);

  final Order o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${qty(o.quantity, o.product.unit)} ${o.product.shortLabel} · ${naira(o.driverFare)}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Load at ${o.depot.name}, deliver to ${o.destination.address} (${o.distanceKm.toStringAsFixed(0)} km).'),
            Text('Requested by ${o.customerName} · ${whenShort(o.createdAt)}', style: t.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => ref.read(ordersProvider.notifier).driverDecline(o.id),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: () => ref.read(ordersProvider.notifier).driverAccept(o.id),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const RoleAppBar(title: 'Driver'),
      body: EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'Register your truck',
        body: 'To haul on Ontero we need your truck details, photos, calibration certificate, licence and a liveness check. Verified drivers get paid from escrow: half when loaded, half on delivery.',
        action: FilledButton(onPressed: () => context.push('/driver/onboarding'), child: const Text('Start registration')),
      ),
    );
  }
}
