import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/truck.dart';
import '../../widgets/common.dart';

/// Guided selfie sequence. A real liveness vendor (face match + anti-spoof)
/// replaces the fake analysis at the end; the capture flow stays the same.
class LivenessCheck extends StatefulWidget {
  const LivenessCheck({super.key, required this.onPassed});

  final ValueChanged<CapturedPhoto> onPassed;

  @override
  State<LivenessCheck> createState() => _LivenessCheckState();
}

class _LivenessCheckState extends State<LivenessCheck> {
  static const _prompts = [
    ('Look straight at the camera', Icons.face),
    ('Turn your head to the left', Icons.arrow_back),
    ('Smile for the camera', Icons.sentiment_satisfied_alt),
  ];

  final _shots = <CapturedPhoto?>[null, null, null];
  bool _analysing = false;
  bool _passed = false;

  int get _next => _shots.indexWhere((s) => s == null);

  Future<void> _analyse() async {
    setState(() => _analysing = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _analysing = false;
      _passed = true;
    });
    widget.onPassed(_shots.first!);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_passed) {
      return Card(
        color: Colors.green.shade50,
        child: const ListTile(
          leading: Icon(Icons.verified_user, color: Colors.green),
          title: Text('Liveness check passed'),
          subtitle: Text('Selfies matched and no spoofing detected.'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Three quick selfies prove a real person is behind this account.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        for (var i = 0; i < _prompts.length; i++)
          Opacity(
            opacity: i <= _next || _next == -1 ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: i > _next && _next != -1,
              child: PhotoCaptureTile(
                label: 'Step ${i + 1}',
                hint: _prompts[i].$1,
                photo: _shots[i],
                preferFront: true,
                onCaptured: (p) => setState(() => _shots[i] = p),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (_analysing)
          Row(children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Checking for a live face…', style: TextStyle(color: scheme.primary)),
          ])
        else
          OutlinedButton.icon(
            onPressed: _next == -1 ? _analyse : null,
            icon: const Icon(Icons.security),
            label: const Text('Run liveness check'),
          ),
      ],
    );
  }
}
