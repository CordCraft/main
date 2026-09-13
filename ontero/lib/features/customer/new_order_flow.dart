import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/data/seed_data.dart';
import '../../core/models/depot.dart';
import '../../core/models/order.dart';
import '../../core/models/product.dart';
import '../../core/models/truck.dart';
import '../../core/models/user.dart';
import '../../core/services/pricing.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';

/// Four-step wizard: product and quantity → depot → destination → truck.
class NewOrderFlow extends ConsumerStatefulWidget {
  const NewOrderFlow({super.key});

  @override
  ConsumerState<NewOrderFlow> createState() => _NewOrderFlowState();
}

class _NewOrderFlowState extends ConsumerState<NewOrderFlow> {
  int _step = 0;
  ProductType _product = ProductType.pms;
  int _quantity = 33000;
  Depot? _depot;
  LatLng? _dest;
  String _destLabel = '';
  final _address = TextEditingController();
  AppUser? _driver;

  static const _titles = ['What are you lifting?', 'Pick a depot', 'Where should it go?', 'Choose a truck'];

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
        0 => _quantity > 0,
        1 => _depot != null,
        2 => _dest != null && _address.text.trim().isNotEmpty,
        _ => _driver != null,
      };

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    final me = ref.read(sessionProvider)!;
    final order = ref.read(ordersProvider.notifier).create(
          customer: me,
          product: _product,
          quantity: _quantity,
          depot: _depot!,
          destination: DeliveryPoint(label: _destLabel.isEmpty ? _address.text.trim() : _destLabel, address: _address.text.trim(), location: _dest!),
          driver: _driver!,
        );
    context.pushReplacement('/orders/${order.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_step]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _step == 0 ? context.pop() : setState(() => _step--),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_step + 1) / 4, minHeight: 4),
          Expanded(
            child: switch (_step) {
              0 => _ProductStep(
                  product: _product,
                  quantity: _quantity,
                  onChanged: (p, q) => setState(() {
                    _product = p;
                    _quantity = q;
                    if (_depot != null && !_depot!.products.contains(p)) _depot = null;
                    _driver = null;
                  }),
                ),
              1 => _DepotStep(
                  product: _product,
                  selected: _depot,
                  onSelect: (d) => setState(() {
                    _depot = d;
                    _driver = null;
                  }),
                ),
              2 => _DestinationStep(
                  depot: _depot!,
                  selected: _dest,
                  address: _address,
                  onSelect: (p, label) => setState(() {
                    _dest = p;
                    _destLabel = label;
                    if (label.isNotEmpty && _address.text.trim().isEmpty) _address.text = label;
                    _driver = null;
                  }),
                ),
              _ => _TruckStep(
                  product: _product,
                  quantity: _quantity,
                  depot: _depot!,
                  destination: _dest!,
                  selected: _driver,
                  onSelect: (d) => setState(() => _driver = d),
                ),
            },
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _canContinue ? _next : null,
                child: Text(_step == 3 ? 'Request this driver' : 'Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ProductStep extends StatelessWidget {
  const _ProductStep({required this.product, required this.quantity, required this.onChanged});

  final ProductType product;
  final int quantity;
  final void Function(ProductType, int) onChanged;

  List<int> _presets(ProductType p) => p == ProductType.lpg ? [5000, 10000, 20000] : [33000, 45000, 60000];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in ProductType.values)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: p == product ? Theme.of(context).colorScheme.primaryContainer : null,
            child: ListTile(
              leading: ProductIcon(p),
              title: Text(p.label),
              subtitle: Text('Sold per ${p.unit == 'kg' ? 'kilogram' : 'litre'} · ${naira(SeedData.basePrice(p))}/${p.unit} indicative'),
              trailing: p == product ? const Icon(Icons.check_circle) : null,
              onTap: () => onChanged(p, _presets(p).first),
            ),
          ),
        const SectionTitle('Quantity'),
        Wrap(
          spacing: 8,
          children: [
            for (final q in _presets(product))
              ChoiceChip(label: Text(qty(q, product.unit)), selected: quantity == q, onSelected: (_) => onChanged(product, q)),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('$product-$quantity'),
          initialValue: quantity.toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Custom quantity (${product.unit})', helperText: 'Trucks are matched on capacity, so a full load is usual.'),
          onChanged: (v) {
            final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
            if (n != null && n > 0) onChanged(product, n);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _DepotStep extends ConsumerStatefulWidget {
  const _DepotStep({required this.product, required this.selected, required this.onSelect});

  final ProductType product;
  final Depot? selected;
  final ValueChanged<Depot> onSelect;

  @override
  ConsumerState<_DepotStep> createState() => _DepotStepState();
}

class _DepotStepState extends ConsumerState<_DepotStep> {
  final _map = MapController();
  bool _showMap = true;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(depotsProvider).where((d) => d.products.contains(widget.product)).toList();
    final depots = _query.isEmpty
        ? all
        : all.where((d) => '${d.name} ${d.city} ${d.state} ${d.operator}'.toLowerCase().contains(_query.toLowerCase())).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search depot, city or operator', isDense: true),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, icon: Icon(Icons.map_outlined)),
                  ButtonSegment(value: false, icon: Icon(Icons.list)),
                ],
                selected: {_showMap},
                onSelectionChanged: (s) => setState(() => _showMap = s.first),
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
        if (_showMap)
          Expanded(
            flex: 3,
            child: DepotMap(
              depots: depots,
              selected: widget.selected,
              controller: _map,
              onSelect: (d) {
                widget.onSelect(d);
                _map.move(d.location, 9);
              },
            ),
          ),
        Expanded(
          flex: _showMap ? 2 : 5,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: depots.length,
            itemBuilder: (_, i) {
              final d = depots[i];
              final sel = widget.selected?.id == d.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: sel ? Theme.of(context).colorScheme.primaryContainer : null,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.factory_outlined),
                  title: Text(d.name),
                  subtitle: Text('${d.operator} · ${d.shortLocation}\n${d.products.map((p) => p.code).join(' · ')}'),
                  isThreeLine: true,
                  trailing: sel ? const Icon(Icons.check_circle) : null,
                  onTap: () {
                    widget.onSelect(d);
                    if (_showMap) _map.move(d.location, 9);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _DestinationStep extends StatefulWidget {
  const _DestinationStep({required this.depot, required this.selected, required this.address, required this.onSelect});

  final Depot depot;
  final LatLng? selected;
  final TextEditingController address;
  final void Function(LatLng, String label) onSelect;

  @override
  State<_DestinationStep> createState() => _DestinationStepState();
}

class _DestinationStepState extends State<_DestinationStep> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sel = widget.selected;
    final km = sel == null ? null : Pricing.roadKm(widget.depot.location, sel);
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: widget.depot.location,
                  initialZoom: 7,
                  onTap: (_, point) => widget.onSelect(point, ''),
                ),
                children: [
                  osmTiles(),
                  if (sel != null)
                    PolylineLayer(polylines: [Polyline(points: [widget.depot.location, sel], color: scheme.primary, strokeWidth: 3)]),
                  MarkerLayer(
                    markers: [
                      Marker(point: widget.depot.location, width: 36, height: 36, alignment: Alignment.topCenter, child: Icon(Icons.factory, color: scheme.primary, size: 30)),
                      if (sel != null)
                        Marker(point: sel, width: 40, height: 40, alignment: Alignment.topCenter, child: Icon(Icons.location_on, color: scheme.secondary, size: 38)),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      sel == null ? 'Tap the map to drop a pin, or pick a city below.' : 'Roughly ${km!.toStringAsFixed(0)} km by road from ${widget.depot.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: widget.address,
                decoration: const InputDecoration(labelText: 'Delivery address', hintText: 'Filling station, plant or site address', prefixIcon: Icon(Icons.place_outlined)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in SeedData.quickDestinations.entries)
                    ChoiceChip(
                      label: Text(e.key),
                      selected: sel == e.value,
                      onSelected: (_) {
                        widget.onSelect(e.value, e.key);
                        _map.move(e.value, 9);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _TruckStep extends ConsumerWidget {
  const _TruckStep({
    required this.product,
    required this.quantity,
    required this.depot,
    required this.destination,
    required this.selected,
    required this.onSelect,
  });

  final ProductType product;
  final int quantity;
  final Depot depot;
  final LatLng destination;
  final AppUser? selected;
  final ValueChanged<AppUser> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(usersProvider);
    final me = ref.watch(sessionProvider)!;
    final drivers = ref.read(usersProvider.notifier).matchingDrivers(product: product, quantity: quantity, depot: depot, excludeUserId: me.id);
    final km = Pricing.roadKm(depot.location, destination);

    if (drivers.isEmpty) {
      return EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No matching trucks right now',
        body: 'No verified truck can carry ${qty(quantity, product.unit)} of ${product.shortLabel}. Try a smaller quantity or another product.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Verified trucks rated for ${product.shortLabel} with at least ${qty(quantity, product.unit)} capacity, nearest to ${depot.name} first. '
          'Fares cover ${km.toStringAsFixed(0)} km by road.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final u in drivers) _DriverCard(user: u, depot: depot, km: km, selected: selected?.id == u.id, onTap: () => onSelect(u)),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.user, required this.depot, required this.km, required this.selected, required this.onTap});

  final AppUser user;
  final Depot depot;
  final double km;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = user.driver!;
    final t = Theme.of(context).textTheme;
    final fare = Pricing.driverFare(d.truck.truckClass, km);
    final away = Pricing.straightLineKm(d.location, depot.location);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Text(user.initials)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(user.name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, size: 16, color: Colors.green),
                          ],
                        ),
                        Text('${d.truck.truckClass.label} · ${d.truck.make} ${d.truck.year}', style: t.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(naira(fare), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text('haulage fare', style: t.bodySmall),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Meta(Icons.star, '${d.rating.toStringAsFixed(1)} · ${d.tripsCompleted} trips'),
                  _Meta(Icons.near_me_outlined, '${away.toStringAsFixed(0)} km from depot · ${d.baseCity}'),
                  _Meta(Icons.fact_check_outlined, 'Calibration to ${dateOnly(d.truck.calibrationExpiry)}'),
                  _Meta(Icons.local_gas_station_outlined, d.truck.products.map((p) => p.code).join('/')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
