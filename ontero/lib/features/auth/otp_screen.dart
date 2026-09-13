import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, required this.name});

  final String phone;
  final String name;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _verify() {
    // SMS OTP provider goes here. Any six digits pass in this build.
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    ref.read(sessionProvider.notifier).signIn(phone: widget.phone, name: widget.name);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the code', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Sent to ${widget.phone}. Use 123456 while SMS is not wired up.'),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: InputDecoration(counterText: '', errorText: _error),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _verify, child: const Text('Verify and continue')),
          ],
        ),
      ),
    );
  }
}
