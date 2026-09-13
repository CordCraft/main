import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../state/providers.dart';
import '../customer/customer_home.dart';
import '../driver/driver_home.dart';
import '../offtaker/offtaker_home.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

/// One shell, three roles. The tab set changes with the active role.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    if (user == null) return const SizedBox.shrink();

    final home = switch (user.activeRole) {
      AppRole.customer => const CustomerHome(),
      AppRole.driver => const DriverHome(),
      AppRole.offtaker => const OfftakerHome(),
    };
    final homeLabel = switch (user.activeRole) {
      AppRole.customer => 'Orders',
      AppRole.driver => 'Jobs',
      AppRole.offtaker => 'Sales',
    };
    final pages = [home, const WalletScreen(embedded: true), const ProfileScreen()];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: homeLabel),
          const NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Bottom sheet that lets the signed-in user change hats.
Future<void> showRoleSwitcher(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final user = ref.read(sessionProvider)!;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('Use Onterra as', style: Theme.of(ctx).textTheme.titleMedium)),
            ),
            for (final role in AppRole.values)
              ListTile(
                leading: Icon(switch (role) {
                  AppRole.customer => Icons.shopping_bag_outlined,
                  AppRole.driver => Icons.local_shipping_outlined,
                  AppRole.offtaker => Icons.storefront_outlined,
                }),
                title: Text(role.label),
                subtitle: Text(_roleSubtitle(user, role)),
                trailing: user.activeRole == role ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () {
                  ref.read(sessionProvider.notifier).switchRole(role);
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

String _roleSubtitle(AppUser user, AppRole role) {
  switch (role) {
    case AppRole.customer:
      return role.description;
    case AppRole.driver:
      final d = user.driver;
      return d == null ? 'Register your truck to start' : '${d.truck.summary} · ${d.effectiveStatus.label}';
    case AppRole.offtaker:
      final o = user.offtaker;
      return o == null ? 'Register your company to start' : '${o.companyName} · ${o.status.label}';
  }
}

/// App bar used by every role home: greeting plus the role switch button.
class RoleAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const RoleAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider)!;
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text('${user.activeRole.label} · ${user.name.split(' ').first}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => showRoleSwitcher(context, ref),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Switch'),
        ),
      ],
    );
  }
}
