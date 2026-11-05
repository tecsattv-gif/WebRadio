import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/lock_service.dart';

const Color _kAccent = Color(0xFFFF8A1F);

/// Chave do Navigator do app (o balão usa a camada dele para aparecer
/// também quando a tela está travada).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Balão escuro com instrução (aparece por alguns segundos).
class _Balloon extends StatelessWidget {
  final String text;
  final bool pointsUp;
  const _Balloon({required this.text, this.pointsUp = true});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (pointsUp)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CustomPaint(size: const Size(14, 8), painter: _ArrowPainter()),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2A211A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kAccent.withValues(alpha: 0.5)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
            ),
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFF2A211A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mostra um balão abaixo do widget [anchor] por alguns segundos.
OverlayEntry? _balloonEntry;
Timer? _balloonTimer;

void _showBalloon(BuildContext anchor, String text) {
  final overlay = appNavigatorKey.currentState?.overlay ?? Overlay.maybeOf(anchor);
  final box = anchor.findRenderObject() as RenderBox?;
  if (overlay == null || box == null || !box.attached) return;
  final pos = box.localToGlobal(Offset.zero, ancestor: overlay.context.findRenderObject());
  final screenW = MediaQuery.sizeOf(anchor).width;
  _balloonTimer?.cancel();
  _balloonEntry?.remove();
  _balloonEntry = OverlayEntry(
    builder: (_) => Positioned(
      top: pos.dy + box.size.height + 2,
      right: (screenW - pos.dx - box.size.width).clamp(8.0, screenW),
      child: IgnorePointer(child: _Balloon(text: text)),
    ),
  );
  overlay.insert(_balloonEntry!);
  _balloonTimer = Timer(const Duration(seconds: 3), _hideBalloon);
}

void _hideBalloon() {
  _balloonTimer?.cancel();
  _balloonEntry?.remove();
  _balloonEntry = null;
}

/// Cadeado FECHADO (no topo): toque mostra como travar; toque longo trava.
class LockButton extends StatelessWidget {
  const LockButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => InkResponse(
        radius: 22,
        onTap: () {
          HapticFeedback.selectionClick();
          _showBalloon(ctx, 'Toque e segure o cadeado para travar a tela.');
        },
        onLongPress: () {
          _hideBalloon();
          LockService.lock();
        },
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.lock_outline_rounded, size: 20, color: Colors.white38),
        ),
      ),
    );
  }
}

/// Camada por cima de tudo enquanto travado: segura os toques e mostra o
/// cadeado ABERTO para destravar (segurando). Tocar na tela mostra a instrução.
class LockOverlay extends StatelessWidget {
  final Widget child;
  const LockOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LockService.locked,
      builder: (context, locked, _) => Stack(
        children: [
          child,
          if (locked) const Positioned.fill(child: _LockedLayer()),
        ],
      ),
    );
  }
}

class _LockedLayer extends StatefulWidget {
  const _LockedLayer();

  @override
  State<_LockedLayer> createState() => _LockedLayerState();
}

class _LockedLayerState extends State<_LockedLayer> with SingleTickerProviderStateMixin {
  final GlobalKey _lockKey = GlobalKey();
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _hideBalloon();
        LockService.unlock();
      }
    });

  @override
  void dispose() {
    _hold.dispose();
    _hideBalloon();
    super.dispose();
  }

  void _hint() {
    final ctx = _lockKey.currentContext;
    if (ctx != null) {
      HapticFeedback.selectionClick();
      _showBalloon(ctx, 'Tela travada. Toque e segure o cadeado aberto para destravar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        // Segura todos os toques da tela; um toque mostra a instrução.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _hint,
            onLongPress: _hint,
            onVerticalDragStart: (_) {},
            onHorizontalDragStart: (_) {},
          ),
        ),
        Positioned(
          top: top + 4,
          right: 8,
          child: GestureDetector(
            key: _lockKey,
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _hold.forward(from: 0),
            onTapUp: (_) {
              if (_hold.value < 0.25) _hint();
              _hold.reverse();
            },
            onTapCancel: () => _hold.reverse(),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: AnimatedBuilder(
                animation: _hold,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: _hold.value,
                        strokeWidth: 3,
                        color: _kAccent,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const Icon(Icons.lock_open_rounded, color: _kAccent, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
