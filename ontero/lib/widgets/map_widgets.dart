import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/models/depot.dart';

/// OpenStreetMap tile layer used across the app (no API key required).
TileLayer osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.ontero.app',
    );

class DepotMarker extends StatelessWidget {
  const DepotMarker({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.location_on,
      size: selected ? 40 : 30,
      color: selected ? scheme.secondary : scheme.primary,
      shadows: const [Shadow(color: Colors.black38, blurRadius: 6)],
    );
  }
}

/// Map of depots with tap-to-select markers.
class DepotMap extends StatelessWidget {
  const DepotMap({
    super.key,
    required this.depots,
    required this.selected,
    required this.onSelect,
    required this.controller,
  });

  final List<Depot> depots;
  final Depot? selected;
  final ValueChanged<Depot> onSelect;
  final MapController controller;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: const MapOptions(initialCenter: LatLng(8.0, 6.5), initialZoom: 5.6),
      children: [
        osmTiles(),
        MarkerLayer(
          markers: [
            for (final d in depots)
              Marker(
                point: d.location,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => onSelect(d),
                  child: DepotMarker(selected: selected?.id == d.id),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Map that shows the depot, the drop-off pin and the line between them.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, required this.from, required this.to, this.height = 200, this.truckAt});

  final LatLng from;
  final LatLng to;
  final LatLng? truckAt;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints([from, to]),
              padding: const EdgeInsets.all(40),
            ),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            osmTiles(),
            PolylineLayer(polylines: [Polyline(points: [from, to], color: scheme.primary, strokeWidth: 3)]),
            MarkerLayer(
              markers: [
                Marker(point: from, width: 36, height: 36, alignment: Alignment.topCenter, child: Icon(Icons.factory, color: scheme.primary, size: 30)),
                Marker(point: to, width: 36, height: 36, alignment: Alignment.topCenter, child: Icon(Icons.location_on, color: scheme.secondary, size: 34)),
                if (truckAt != null)
                  Marker(point: truckAt!, width: 32, height: 32, child: const Icon(Icons.local_shipping, color: Colors.black87, size: 26)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
