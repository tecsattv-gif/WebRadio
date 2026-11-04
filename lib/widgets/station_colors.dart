import 'dart:math';

import 'package:flutter/material.dart';

import '../models/station.dart';
import 'station_logo.dart';

/// Cor de destaque de cada rádio, tirada do logo (com cache).
class StationColors {
  static final Map<String, Color> _cache = {};
  static final Set<String> _pending = {};

  /// Muda quando uma cor nova fica pronta (para redesenhar a tela).
  static final ValueNotifier<int> version = ValueNotifier(0);

  static Color fallback(Station s) =>
      HSLColor.fromAHSL(1, (s.name.hashCode % 360).toDouble(), 0.50, 0.32).toColor();

  static String _key(Station s) =>
      '${s.id}:${s.logoData?.length ?? 0}:${s.logoUrl ?? ''}';

  static Color of(Station s) {
    final key = _key(s);
    final c = _cache[key];
    if (c != null) return c;
    _compute(s, key);
    return fallback(s);
  }

  static Future<void> _compute(Station s, String key) async {
    if (_pending.contains(key)) return;
    _pending.add(key);
    ImageProvider? provider;
    final bytes = StationLogo.bytesOf(s.logoData);
    if (bytes != null) {
      provider = MemoryImage(bytes);
    } else if ((s.logoUrl ?? '').trim().isNotEmpty) {
      provider = NetworkImage(s.logoUrl!.trim());
    }
    if (provider == null) {
      _cache[key] = fallback(s);
      return;
    }
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: Brightness.dark,
      );
      final hsl = HSLColor.fromColor(scheme.primary);
      _cache[key] = hsl
          .withLightness(0.34)
          .withSaturation(min(max(hsl.saturation, 0.25), 0.65))
          .toColor();
    } catch (_) {
      _cache[key] = fallback(s);
    }
    version.value++;
  }
}
