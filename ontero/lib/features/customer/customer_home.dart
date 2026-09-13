import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/order.dart';
import '../../core/models/product.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../shell/home_shell.dart';

class CustomerHome extends ConsumerWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    final open = orders.where((o) => o.status.isOpen).toList();
    final closed = orders.where((o) => !o.status.isOpen).toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const RoleAppBar(title: 'Ontero'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders/new'),
        icon: const Icon(Icons.add),
        label: const Text('New delivery'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Need product delivered?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('Pick a depot, choose a verified truck, pay into escrow. Sellers only get paid when your truck is loaded.'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 4,
                    children: [for (final p in ProductType.values.take(4)) Icon(p.icon, color: p.color, size: 20)],
                  ),
                ],
              ),
            ),
          ),
          SectionTitle('Active orders (${open.length})'),
          if (open.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No active orders. Tap "New delivery" to lift your first load.'),
              ),
            )
          else
            for (final o in open) OrderCard(o),
          if (closed.isNotEmpty) ...[
            const SectionTitle('History'),
            for (final o in closed) OrderCard(o),
          ],
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard(this.order, {super.key, this.subtitleOverride});

  final Order order;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ProductIcon(order.product),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${qty(order.quantity, order.product.unit)} ${order.product.shortLabel}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                        StatusChip(order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitleOverride ?? '${order.depot.name} to ${order.destination.label}', style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${order.reference} · ${whenShort(order.createdAt)}', style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
