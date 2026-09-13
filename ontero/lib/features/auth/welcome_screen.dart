import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: OnteroTheme.teal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: OnteroTheme.amber, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.local_shipping_rounded, color: OnteroTheme.ink, size: 36),
              ),
              const SizedBox(height: 24),
              Text('Ontero', style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Petrol, diesel, kerosene and cooking gas delivered from the depot to your door. '
                'Pick a depot, lock in a verified truck, pay into escrow, and track the lift.',
                style: t.bodyLarge?.copyWith(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 32),
              const _Step(icon: Icons.map_outlined, text: 'Choose product, depot and destination'),
              const _Step(icon: Icons.verified_user_outlined, text: 'Match with a verified truck and seller'),
              const _Step(icon: Icons.lock_outline, text: 'Money sits in escrow until the lift happens'),
              const Spacer(flex: 2),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: OnteroTheme.amber, foregroundColor: OnteroTheme.ink),
                onPressed: () => context.go('/login'),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('One account for customers, drivers and offtakers', style: t.bodySmall?.copyWith(color: Colors.white60)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: OnteroTheme.amber),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15))),
        ],
      ),
    );
  }
}
