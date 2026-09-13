import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/models/order.dart';
import '../core/models/product.dart';
import '../core/models/truck.dart';
import '../core/models/user.dart';

final _naira = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
final _nairaCents = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
final _number = NumberFormat.decimalPattern('en_NG');
final _dateTime = DateFormat('d MMM, HH:mm');
final _date = DateFormat('d MMM yyyy');

String naira(double v) => _naira.format(v);
String nairaExact(double v) => _nairaCents.format(v);
String qty(int v, String unit) => '${_number.format(v)} $unit';
String whenShort(DateTime d) => _dateTime.format(d);
String dateOnly(DateTime d) => _date.format(d);

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      OrderStatus.completed => (Colors.green.shade100, Colors.green.shade900),
      OrderStatus.cancelled => (scheme.errorContainer, scheme.onErrorContainer),
      OrderStatus.awaitingDriver => (Colors.orange.shade100, Colors.orange.shade900),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class VerificationBadge extends StatelessWidget {
  const VerificationBadge(this.status, {super.key});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      VerificationStatus.approved => (Icons.verified, Colors.green.shade700),
      VerificationStatus.pending => (Icons.hourglass_top, Colors.orange.shade800),
      VerificationStatus.rejected => (Icons.cancel, Colors.red.shade700),
      VerificationStatus.expired => (Icons.update, Colors.red.shade700),
      VerificationStatus.notStarted => (Icons.radio_button_unchecked, Colors.grey),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(status.label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}

class ProductIcon extends StatelessWidget {
  const ProductIcon(this.product, {super.key, this.size = 40});

  final ProductType product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: product.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size / 4)),
      child: Icon(product.icon, color: product.color, size: size * 0.55),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: t.bodyMedium?.copyWith(color: t.bodySmall?.color))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: emphasize ? t.titleMedium?.copyWith(fontWeight: FontWeight.w700) : t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Camera or gallery capture tile that stores the image bytes in memory.
class PhotoCaptureTile extends StatefulWidget {
  const PhotoCaptureTile({
    super.key,
    required this.label,
    required this.hint,
    required this.onCaptured,
    this.photo,
    this.preferFront = false,
  });

  final String label;
  final String hint;
  final CapturedPhoto? photo;
  final bool preferFront;
  final ValueChanged<CapturedPhoto> onCaptured;

  @override
  State<PhotoCaptureTile> createState() => _PhotoCaptureTileState();
}

class _PhotoCaptureTileState extends State<PhotoCaptureTile> {
  bool _busy = false;

  Future<void> _capture(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
        preferredCameraDevice: widget.preferFront ? CameraDevice.front : CameraDevice.rear,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      widget.onCaptured(CapturedPhoto(label: widget.label, bytes: bytes, takenAt: DateTime.now()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open camera: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = widget.photo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 72,
                child: photo == null
                    ? Container(color: scheme.surfaceContainerHighest, child: Icon(Icons.photo_camera_outlined, color: scheme.outline))
                    : Image.memory(photo.bytes, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(widget.hint, style: Theme.of(context).textTheme.bodySmall),
                  if (photo != null)
                    Text('Captured ${whenShort(photo.takenAt)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade700)),
                ],
              ),
            ),
            if (_busy)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              PopupMenuButton<ImageSource>(
                icon: Icon(photo == null ? Icons.add_a_photo_outlined : Icons.refresh),
                onSelected: _capture,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: ImageSource.camera, child: Text('Take photo')),
                  PopupMenuItem(value: ImageSource.gallery, child: Text('Choose from gallery')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Small helper used by tests and previews to fabricate a photo.
CapturedPhoto placeholderPhoto(String label) =>
    CapturedPhoto(label: label, bytes: Uint8List(0), takenAt: DateTime.now());
