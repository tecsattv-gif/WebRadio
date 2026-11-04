import 'dart:math';

import 'package:flutter/material.dart';

/// Barrinhas de equalizador animadas (param quando [active] é falso).
class Equalizer extends StatefulWidget {
  final bool active;
  final Color color;
  final double size;
  final int bars;

  const Equalizer({
    super.key,
    required this.active,
    required this.color,
    this.size = 18,
    this.bars = 4,
  });

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant Equalizer old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barW = widget.size / (widget.bars * 1.7);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * pi;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.bars, (i) {
              final h = widget.active
                  ? 0.25 + 0.75 * (0.5 + 0.5 * sin(t * (1 + i % 3) + i * 1.9)).abs()
                  : 0.25;
              return Container(
                width: barW,
                height: widget.size * h,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(barW),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
