import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../shell/home_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider)!;
    final scheme = Theme.of(context).colorScheme;
    final driver = user.driver;
    final offtaker = user.offtaker;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(radius: 28, backgroundColor: scheme.primary, child: Text(user.initials, style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 20))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                    Text(user.phone, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SectionTitle('Roles'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: const Text('Customer'),
                  subtitle: const Text('Always available'),
                  trailing: const VerificationBadge(VerificationStatus.approved),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: const Text('Driver'),
                  subtitle: Text(driver == null ? 'Register your truck and pass the liveness check' : driver.truck.summary),
                  trailing: VerificationBadge(driver?.effectiveStatus ?? VerificationStatus.notStarted),
                  onTap: () => context.push(driver == null || driver.effectiveStatus == VerificationStatus.expired ? (driver == null ? '/driver/onboarding' : '/driver/recheck') : '/driver/onboarding'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Offtaker / seller'),
                  subtitle: Text(offtaker == null ? 'Register your company and proof of product' : offtaker.companyName),
                  trailing: VerificationBadge(offtaker?.status ?? VerificationStatus.notStarted),
                  onTap: () => context.push('/offtaker/onboarding'),
                ),
              ],
            ),
          ),
          const SectionTitle('Account'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Switch role'),
                  subtitle: Text('Currently using Ontero as ${user.activeRole.label.toLowerCase()}'),
                  onTap: () => showRoleSwitcher(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.account_balance_outlined),
                  title: const Text('Payout bank account'),
                  subtitle: Text(user.bankAccount?.masked ?? 'Not linked'),
                  onTap: () => context.push('/profile/bank'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: scheme.error),
                  title: Text('Sign out', style: TextStyle(color: scheme.error)),
                  onTap: () => ref.read(sessionProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Ontero · platform fee 5% per transaction', style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
