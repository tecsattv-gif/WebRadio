import 'package:flutter/material.dart';

import '../services/lock_service.dart';

/// Botão discreto do cadeado (no topo). Toca para travar.
class LockButton extends StatelessWidget {
  const LockButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Travar a tela',
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      icon: const Icon(Icons.lock_open_rounded, color: Colors.white38),
      onPressed: () {
        LockService.lock();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Tela travada. Segure o cadeado por 2 segundos para destravar.'),
            duration: Duration(seconds: 3),
          ));
      },
    );
  }
}

/// Camada por cima de tudo enquanto travado: segura os toques e mostra
/// o cadeado para destravar (segurando 2 s).
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
          if (locked)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                onLongPress: () {},
                onVerticalDragStart: (_) {},
                onHorizontalDragStart: (_) {},
                child: const SizedBox.expand(),
              ),
            ),
          if (locked)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              right: 10,
              child: const _HoldToUnlock(),
            ),
        ],
      ),
    );
  }
}

class _HoldToUnlock extends StatefulWidget {
  const _HoldToUnlock();

  @override
  State<_HoldToUnlock> createState() => _HoldToUnlockState();
}

class _HoldToUnlockState extends State<_HoldToUnlock> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        LockService.unlock();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _c.forward(from: 0),
      onTapUp: (_) => _c.reverse(),
      onTapCancel: () => _c.reverse(),
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _c.value,
                        strokeWidth: 3,
                        color: const Color(0xFFFF8A1F),
                        backgroundColor: Colors.white12,
                      ),
                      const Icon(Icons.lock_rounded, color: Color(0xFFFF8A1F), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Segure para destravar',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
