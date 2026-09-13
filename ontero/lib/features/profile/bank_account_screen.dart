import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user.dart';
import '../../state/providers.dart';

const nigerianBanks = [
  'Access Bank', 'Ecobank', 'Fidelity Bank', 'First Bank', 'FCMB', 'GTBank', 'Keystone Bank', 'Kuda',
  'Moniepoint', 'OPay', 'Polaris Bank', 'Providus Bank', 'Stanbic IBTC', 'Sterling Bank', 'UBA', 'Union Bank',
  'Unity Bank', 'Wema Bank', 'Zenith Bank',
];

class BankAccountScreen extends ConsumerStatefulWidget {
  const BankAccountScreen({super.key});

  @override
  ConsumerState<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends ConsumerState<BankAccountScreen> {
  final _form = GlobalKey<FormState>();
  String? _bank;
  final _number = TextEditingController();
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(sessionProvider)?.bankAccount;
    if (existing != null) {
      _bank = existing.bankName;
      _number.text = existing.accountNumber;
      _name.text = existing.accountName;
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    ref.read(sessionProvider.notifier).setBankAccount(
          BankAccount(bankName: _bank!, accountNumber: _number.text.trim(), accountName: _name.text.trim()),
        );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout account')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Escrow releases are paid to this account. Account name verification (NUBAN lookup) plugs in here.'),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _bank,
              decoration: const InputDecoration(labelText: 'Bank'),
              items: [for (final b in nigerianBanks) DropdownMenuItem(value: b, child: Text(b))],
              onChanged: (v) => setState(() => _bank = v),
              validator: (v) => v == null ? 'Choose a bank' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: const InputDecoration(labelText: 'Account number (NUBAN)', counterText: ''),
              validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? '') ? null : '10 digits required',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Account name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Save account')),
          ],
        ),
      ),
    );
  }
}
