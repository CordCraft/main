import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/truck.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'liveness_check.dart';

/// Monthly proof that the driver still has the truck and is the same person.
class DriverRecheckScreen extends ConsumerStatefulWidget {
  const DriverRecheckScreen({super.key});

  @override
  ConsumerState<DriverRecheckScreen> createState() => _DriverRecheckScreenState();
}

class _DriverRecheckScreenState extends ConsumerState<DriverRecheckScreen> {
  CapturedPhoto? _truck;
  CapturedPhoto? _selfie;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sessionProvider)!.driver!;
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly re-check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Take a fresh photo of ${d.truck.plate} showing the plate, then pass a liveness check. This keeps your truck visible to customers.'),
          const SectionTitle('Truck today'),
          PhotoCaptureTile(
            label: 'Front with plate',
            hint: 'Same truck, plate readable, taken now',
            photo: _truck,
            onCaptured: (p) => setState(() => _truck = p),
          ),
          const SectionTitle('Liveness check'),
          LivenessCheck(onPassed: (p) => setState(() => _selfie = p)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _truck != null && _selfie != null
                ? () {
                    ref.read(sessionProvider.notifier).completeDriverRecheck(selfie: _selfie!, truckPhoto: _truck!);
                    context.pop();
                  }
                : null,
            child: const Text('Submit re-check'),
          ),
        ],
      ),
    );
  }
}
