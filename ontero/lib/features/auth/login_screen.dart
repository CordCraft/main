import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  String _normalise(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('0')) digits = '+234${digits.substring(1)}';
    if (!digits.startsWith('+')) digits = '+234$digits';
    return digits;
  }

  void _continue() {
    if (!_form.currentState!.validate()) return;
    final phone = _normalise(_phone.text);
    context.push('/otp?phone=${Uri.encodeComponent(phone)}&name=${Uri.encodeComponent(_name.text.trim())}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Sign in with your phone', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('We will send a one-time code by SMS. New numbers get a customer account straight away.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined), hintText: '0803 123 4567'),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  return digits.length < 10 ? 'Enter a valid Nigerian number' : null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _continue, child: const Text('Send code')),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Try a demo account', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      const Text('Sign in as a seeded driver or seller to see their side of an order:'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(label: const Text('Driver: Musa'), onPressed: () => _fill('Musa Abdullahi', '+2348031000001')),
                          ActionChip(label: const Text('Seller: Lagos Fuels'), onPressed: () => _fill('Adaeze Okafor', '+2348021000001')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _fill(String name, String phone) {
    _name.text = name;
    _phone.text = phone;
  }
}
