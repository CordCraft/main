import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/customer/new_order_flow.dart';
import '../features/customer/order_detail_screen.dart';
import '../features/customer/select_seller_screen.dart';
import '../features/driver/driver_onboarding_screen.dart';
import '../features/driver/driver_recheck_screen.dart';
import '../features/offtaker/new_listing_screen.dart';
import '../features/offtaker/offtaker_onboarding_screen.dart';
import '../features/profile/bank_account_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/wallet/wallet_screen.dart';
import '../state/providers.dart';

/// Bridges Riverpod session state into go_router's refreshListenable.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: listenable,
    redirect: (context, state) {
      final signedIn = ref.read(sessionProvider) != null;
      final path = state.uri.path;
      final onAuth = path == '/welcome' || path == '/login' || path.startsWith('/otp');
      if (!signedIn && !onAuth) return '/welcome';
      if (signedIn && onAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) => OtpScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
          name: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/orders/new', builder: (_, __) => const NewOrderFlow()),
      GoRoute(path: '/orders/:id', builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/orders/:id/seller', builder: (_, state) => SelectSellerScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/driver/onboarding', builder: (_, __) => const DriverOnboardingScreen()),
      GoRoute(path: '/driver/recheck', builder: (_, __) => const DriverRecheckScreen()),
      GoRoute(path: '/offtaker/onboarding', builder: (_, __) => const OfftakerOnboardingScreen()),
      GoRoute(path: '/offtaker/listings/new', builder: (_, __) => const NewListingScreen()),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/profile/bank', builder: (_, __) => const BankAccountScreen()),
    ],
  );
});
