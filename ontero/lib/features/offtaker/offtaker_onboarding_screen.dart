import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/truck.dart';
import '../../core/models/user.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Offtaker gate: company registration, regulator licence and payout account.
/// Proof of product is added per depot afterwards, and every listing must cite one.
class OfftakerOnboardingScreen extends ConsumerStatefulWidget {
  const OfftakerOnboardingScreen({super.key});

  @override
  ConsumerState<OfftakerOnboardingScreen> createState() => _OfftakerOnboardingScreenState();
}

class _OfftakerOnboardingScreenState extends ConsumerState<OfftakerOnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _rc = TextEditingController();
  final _licence = TextEditingController();
  CapturedPhoto? _licencePhoto;
  CapturedPhoto? _cacPhoto;

  @override
  void dispose() {
    _company.dispose();
    _rc.dispose();
    _licence.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (_licencePhoto == null || _cacPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload both documents first')));
      return;
    }
    ref.read(sessionProvider.notifier).submitOfftakerApplication(OfftakerProfile(
          companyName: _company.text.trim(),
          rcNumber: _rc.text.trim().toUpperCase(),
          licenceNumber: _licence.text.trim().toUpperCase(),
          licencePhoto: _licencePhoto,
        ));
    ref.read(sessionProvider.notifier).switchRole(AppRole.offtaker);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(sessionProvider)?.offtaker;
    if (existing != null && existing.status != VerificationStatus.rejected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seller verification')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(existing.companyName),
                subtitle: Text('${existing.rcNumber} · ${existing.licenceNumber}'),
                trailing: VerificationBadge(existing.status),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  InfoRow('Proofs of product on file', '${existing.proofs.length} (${existing.validProofs.length} valid)'),
                  InfoRow('Orders fulfilled', '${existing.ordersFulfilled}'),
                  InfoRow('Verified on', existing.verifiedAt == null ? 'Pending' : dateOnly(existing.verifiedAt!)),
                ]),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Register as a seller')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text('Buyers only see listings backed by a valid proof of product, and sellers are paid from escrow only after the depot loads the truck.'),
            const SectionTitle('Company'),
            TextFormField(
              controller: _company,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Registered company name'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _rc,
              decoration: const InputDecoration(labelText: 'CAC registration (RC) number'),
              validator: (v) => (v ?? '').trim().length < 4 ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            PhotoCaptureTile(
              label: 'CAC certificate',
              hint: 'Certificate of incorporation',
              photo: _cacPhoto,
              onCaptured: (p) => setState(() => _cacPhoto = p),
            ),
            const SectionTitle('Regulator licence'),
            TextFormField(
              controller: _licence,
              decoration: const InputDecoration(labelText: 'NMDPRA licence / permit number'),
              validator: (v) => (v ?? '').trim().length < 4 ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            PhotoCaptureTile(
              label: 'NMDPRA licence',
              hint: 'Current marketing or storage licence',
              photo: _licencePhoto,
              onCaptured: (p) => setState(() => _licencePhoto = p),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: const Text('Submit for verification')),
          ],
        ),
      ),
    );
  }
}
