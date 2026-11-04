import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/station.dart';

/// Logo da rádio (link opcional) ou as iniciais num quadrado colorido.
class StationLogo extends StatelessWidget {
  final Station station;
  final double size;

  const StationLogo({super.key, required this.station, this.size = 48});

  static final Map<String, Uint8List> _cache = {};

  static Uint8List? bytesOf(String? data) {
    if (data == null || data.isEmpty) return null;
    final cached = _cache[data];
    if (cached != null) return cached;
    try {
      final b = base64Decode(data);
      if (_cache.length > 300) _cache.clear();
      _cache[data] = b;
      return b;
    } catch (_) {
      return null;
    }
  }

  String get _initials {
    final words = station.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.26);
    final hue = (station.name.hashCode % 360).toDouble();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.60, 0.30).toColor(),
          ],
        ),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          letterSpacing: 0.5,
        ),
      ),
    );
    final bytes = bytesOf(station.logoData);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          width: size,
          height: size,
          color: Colors.white,
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stack) => fallback,
          ),
        ),
      );
    }
    final logo = station.logoUrl?.trim() ?? '';
    if (logo.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.network(
          logo,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => fallback,
        ),
      ),
    );
  }
}
