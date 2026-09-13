import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'state/providers.dart';

void main() {
  runApp(const ProviderScope(child: OnteroApp()));
}

class OnteroApp extends ConsumerWidget {
  const OnteroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the demo simulator alive for the life of the app.
    ref.watch(demoSimulatorProvider);
    return MaterialApp.router(
      title: 'Ontero',
      debugShowCheckedModeBanner: false,
      theme: OnteroTheme.light(),
      darkTheme: OnteroTheme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
