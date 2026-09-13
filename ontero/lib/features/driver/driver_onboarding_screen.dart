import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/product.dart';
import '../../core/models/truck.dart';
import '../../core/models/user.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'liveness_check.dart';

/// Driver gate: truck details, photos, documents and a liveness check.
class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  ConsumerState<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends ConsumerState<DriverOnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _make = TextEditingController();
  final _year = TextEditingController(text: '2019');
  final _licence = TextEditingController();
  final _city = TextEditingController(text: 'Apapa, Lagos');
  TruckClass _class = TruckClass.tanker33;
  late Set<ProductType> _products = {..._class.compatibleProducts};
  DateTime _calibration = DateTime.now().add(const Duration(days: 180));
  final _photos = <String, CapturedPhoto>{};
  CapturedPhoto? _licencePhoto;
  CapturedPhoto? _selfie;

  static const _truckShots = {
    'Front with plate': 'Whole truck, number plate readable',
    'Tank side': 'Full length of the tank with compartment markings',
    'Calibration plate': 'The stamped calibration chart on the tank',
  };

  @override
  void dispose() {
    for (final c in [_plate, _make, _year, _licence, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ready => _photos.length == _truckShots.length && _licencePhoto != null && _selfie != null;

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (!_ready) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add every photo and pass the liveness check first')));
      return;
    }
    final profile = DriverProfile(
      truck: Truck(
        id: 'trk-${DateTime.now().millisecondsSinceEpoch}',
        plate: _plate.text.trim().toUpperCase(),
        truckClass: _class,
        make: _make.text.trim(),
        year: int.tryParse(_year.text) ?? 2019,
        calibrationExpiry: _calibration,
        products: _products,
        photos: _photos.values.toList(),
      ),
      licenceNumber: _licence.text.trim(),
      licencePhoto: _licencePhoto,
      livenessPassedAt: DateTime.now(),
      location: const LatLng(6.45, 3.37),
      baseCity: _city.text.trim(),
    );
    ref.read(sessionProvider.notifier).submitDriverApplication(profile);
    ref.read(sessionProvider.notifier).switchRole(AppRole.driver);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(sessionProvider)?.driver;
    if (existing != null && existing.status != VerificationStatus.notStarted && existing.status != VerificationStatus.rejected) {
      return _StatusView(profile: existing);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Register as a driver')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text('Customers only see verified trucks. Everything here is re-checked every 30 days.'),
            const SectionTitle('Your truck'),
            DropdownButtonFormField<TruckClass>(
              initialValue: _class,
              decoration: const InputDecoration(labelText: 'Truck class'),
              items: [for (final c in TruckClass.values) DropdownMenuItem(value: c, child: Text(c.label))],
              onChanged: (c) => setState(() {
                _class = c!;
                _products = {..._class.compatibleProducts};
              }),
            ),
            const SizedBox(height: 10),
            Text('Products you will carry', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: [
                for (final p in _class.compatibleProducts)
                  FilterChip(
                    label: Text(p.code),
                    selected: _products.contains(p),
                    onSelected: (s) => setState(() => s ? _products.add(p) : _products.remove(p)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Number plate', hintText: 'KJA 412 XY'),
              validator: (v) => (v ?? '').trim().length < 5 ? 'Enter the plate' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _make,
                    decoration: const InputDecoration(labelText: 'Make / model'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year'),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1990 ? 'Year' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Base city (where the truck usually parks)'),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Calibration certificate expiry'),
              subtitle: Text(dateOnly(_calibration)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _calibration,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (d != null) setState(() => _calibration = d);
              },
            ),
            const SectionTitle('Truck photos'),
            for (final e in _truckShots.entries)
              PhotoCaptureTile(
                label: e.key,
                hint: e.value,
                photo: _photos[e.key],
                onCaptured: (p) => setState(() => _photos[e.key] = p),
              ),
            const SectionTitle('Driver documents'),
            TextFormField(
              controller: _licence,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: "Driver's licence number"),
              validator: (v) => (v ?? '').trim().length < 6 ? 'Enter the licence number' : null,
            ),
            const SizedBox(height: 8),
            PhotoCaptureTile(
              label: "Driver's licence",
              hint: 'Front of the card, all four corners visible',
              photo: _licencePhoto,
              onCaptured: (p) => setState(() => _licencePhoto = p),
            ),
            const SectionTitle('Liveness check'),
            LivenessCheck(onPassed: (p) => setState(() => _selfie = p)),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: const Text('Submit for verification')),
          ],
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = profile.truck;
    return Scaffold(
      appBar: AppBar(title: const Text('Driver verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(t.summary),
              subtitle: Text('${t.make} ${t.year} · ${t.products.map((p) => p.code).join('/')}'),
              trailing: VerificationBadge(profile.effectiveStatus),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  InfoRow('Licence', profile.licenceNumber),
                  InfoRow('Calibration valid to', dateOnly(t.calibrationExpiry)),
                  InfoRow('Liveness last passed', profile.livenessPassedAt == null ? 'Never' : whenShort(profile.livenessPassedAt!)),
                  InfoRow('Next re-check due', profile.nextRecheckDue == null ? 'After approval' : dateOnly(profile.nextRecheckDue!)),
                  InfoRow('Photos on file', '${t.photos.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (profile.status == VerificationStatus.pending)
            const Text('Your application is with the compliance team. You will be able to accept jobs as soon as it is approved.'),
          if (profile.effectiveStatus == VerificationStatus.expired)
            FilledButton(onPressed: () => context.push('/driver/recheck'), child: const Text('Complete monthly re-check')),
        ],
      ),
    );
  }
}
