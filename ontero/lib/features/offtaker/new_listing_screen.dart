import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/seed_data.dart';
import '../../core/models/depot.dart';
import '../../core/models/product.dart';
import '../../core/models/truck.dart';
import '../../core/models/user.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Two halves: register a proof of product for a depot, then list against it.
class NewListingScreen extends ConsumerStatefulWidget {
  const NewListingScreen({super.key});

  @override
  ConsumerState<NewListingScreen> createState() => _NewListingScreenState();
}

class _NewListingScreenState extends ConsumerState<NewListingScreen> {
  final _form = GlobalKey<FormState>();
  ProofOfProduct? _proof;
  bool _newProof = false;

  // new proof fields
  Depot? _depot;
  ProductType _product = ProductType.pms;
  final _proofRef = TextEditingController();
  final _proofQty = TextEditingController();
  DateTime _expires = DateTime.now().add(const Duration(days: 21));
  CapturedPhoto? _doc;

  // listing fields
  final _price = TextEditingController();
  final _available = TextEditingController();
  final _min = TextEditingController(text: '33000');

  @override
  void dispose() {
    for (final c in [_proofRef, _proofQty, _price, _available, _min]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final session = ref.read(sessionProvider.notifier);
    var proof = _proof;
    if (_newProof) {
      if (_depot == null || _doc == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a depot and upload the allocation document')));
        return;
      }
      proof = ProofOfProduct(
        id: 'prf-${DateTime.now().millisecondsSinceEpoch}',
        depotId: _depot!.id,
        product: _product,
        quantity: int.parse(_proofQty.text.replaceAll(RegExp(r'[^0-9]'), '')),
        reference: _proofRef.text.trim().toUpperCase(),
        issuedAt: DateTime.now(),
        expiresAt: _expires,
        document: _doc,
      );
      session.addProofOfProduct(proof);
    }
    if (proof == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a proof of product for this listing')));
      return;
    }
    final me = ref.read(sessionProvider)!;
    ref.read(listingsProvider.notifier).create(
          offtaker: me,
          proof: proof,
          pricePerUnit: double.parse(_price.text.replaceAll(RegExp(r'[^0-9.]'), '')),
          availableQuantity: int.parse(_available.text.replaceAll(RegExp(r'[^0-9]'), '')),
          minQuantity: int.parse(_min.text.replaceAll(RegExp(r'[^0-9]'), '')),
        );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider)!;
    final proofs = me.offtaker?.validProofs ?? const [];
    final depots = ref.watch(depotsProvider);
    final product = _newProof ? _product : (_proof?.product ?? ProductType.pms);

    return Scaffold(
      appBar: AppBar(title: const Text('New listing')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const SectionTitle('Proof of product'),
            const Text('Every listing must reference a depot allocation, stock certificate or programme ticket that has not expired. Buyers see the reference and expiry.'),
            const SizedBox(height: 10),
            for (final p in proofs)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: !_newProof && _proof?.id == p.id ? Theme.of(context).colorScheme.primaryContainer : null,
                child: ListTile(
                  leading: ProductIcon(p.product, size: 36),
                  title: Text('${p.reference} · ${SeedData.depotById(p.depotId).name}'),
                  subtitle: Text('${qty(p.quantity, p.product.unit)} ${p.product.shortLabel} · valid to ${dateOnly(p.expiresAt)}'),
                  onTap: () => setState(() {
                    _proof = p;
                    _newProof = false;
                    _available.text = p.quantity.toString();
                    _min.text = p.product == ProductType.lpg ? '5000' : '33000';
                  }),
                ),
              ),
            Card(
              color: _newProof ? Theme.of(context).colorScheme.primaryContainer : null,
              child: ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Register a new proof of product'),
                onTap: () => setState(() => _newProof = true),
              ),
            ),
            if (_newProof) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<Depot>(
                initialValue: _depot,
                decoration: const InputDecoration(labelText: 'Depot'),
                items: [for (final d in depots) DropdownMenuItem(value: d, child: Text('${d.name} (${d.state})', overflow: TextOverflow.ellipsis))],
                onChanged: (d) => setState(() => _depot = d),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ProductType>(
                initialValue: _product,
                decoration: const InputDecoration(labelText: 'Product'),
                items: [for (final p in ProductType.values) DropdownMenuItem(value: p, child: Text(p.label))],
                onChanged: (p) => setState(() {
                  _product = p!;
                  _min.text = p == ProductType.lpg ? '5000' : '33000';
                }),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _proofRef,
                decoration: const InputDecoration(labelText: 'Allocation / ticket reference'),
                validator: (v) => _newProof && (v ?? '').trim().length < 4 ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _proofQty,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Quantity covered (${product.unit})'),
                validator: (v) => _newProof && (int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) <= 0 ? 'Required' : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('Proof expires'),
                subtitle: Text(dateOnly(_expires)),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _expires, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)));
                  if (d != null) setState(() => _expires = d);
                },
              ),
              PhotoCaptureTile(
                label: 'Allocation document',
                hint: 'Depot allocation letter or stock certificate',
                photo: _doc,
                onCaptured: (p) => setState(() => _doc = p),
              ),
            ],
            const SectionTitle('Offer'),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Price per ${product.unit} (₦)', helperText: 'Indicative gantry price today: ${naira(SeedData.basePrice(product))}'),
              validator: (v) => (double.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0) <= 0 ? 'Enter a price' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _available,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Available (${product.unit})'),
                    validator: (v) => (int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) <= 0 ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Minimum (${product.unit})'),
                    validator: (v) => (int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) <= 0 ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: const Text('Publish listing')),
          ],
        ),
      ),
    );
  }
}
