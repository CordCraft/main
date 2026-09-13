import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/ledger.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider)!;
    final ledger = ref.watch(ledgerProvider);
    final entries = ledger.where((e) => e.partyId == user.id).toList();
    final balance = ref.watch(myBalanceProvider);
    final held = ref.read(ledgerProvider.notifier).heldInEscrow();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet'), automaticallyImplyLeading: !embedded),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Net movement on your account', style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8))),
                  const SizedBox(height: 6),
                  Text(naira(balance), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(
                    user.bankAccount == null ? 'No payout account linked' : 'Payouts to ${user.bankAccount!.masked}',
                    style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: scheme.onPrimary, side: BorderSide(color: scheme.onPrimary.withValues(alpha: 0.5)), minimumSize: const Size(0, 40)),
                    onPressed: () => context.push('/profile/bank'),
                    child: Text(user.bankAccount == null ? 'Link bank account' : 'Change bank account'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Held in Onterra escrow (all orders)'),
              subtitle: const Text('Released to drivers and sellers only when the lift and delivery are confirmed'),
              trailing: Text(naira(held), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SectionTitle('Transactions'),
          if (entries.isEmpty)
            const EmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions yet', body: 'Escrow deposits, releases and refunds will appear here.')
          else
            for (final e in entries) _LedgerTile(e),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile(this.e);

  final LedgerEntry e;

  @override
  Widget build(BuildContext context) {
    final positive = e.signedForParty >= 0;
    final (icon, label) = switch (e.kind) {
      LedgerKind.escrowIn => (Icons.lock_outline, 'Paid into escrow'),
      LedgerKind.release => (Icons.payments_outlined, 'Released to you'),
      LedgerKind.refund => (Icons.undo, 'Refunded'),
      LedgerKind.fee => (Icons.percent, 'Platform fee'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: positive ? Colors.green.shade50 : Colors.orange.shade50,
          child: Icon(icon, color: positive ? Colors.green.shade800 : Colors.orange.shade900, size: 20),
        ),
        title: Text('$label · ${e.orderReference}'),
        subtitle: Text('${e.note}\n${whenShort(e.at)}'),
        isThreeLine: true,
        trailing: Text(
          '${positive ? '+' : '-'}${naira(e.amount)}',
          style: TextStyle(fontWeight: FontWeight.w700, color: positive ? Colors.green.shade800 : Colors.orange.shade900),
        ),
      ),
    );
  }
}
