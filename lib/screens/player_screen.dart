import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/radio_handler.dart';
import '../services/lock_service.dart';
import '../widgets/bluetooth_button.dart';
import '../widgets/lock_overlay.dart';
import '../widgets/now_playing_card.dart';
import '../widgets/station_colors.dart';
import '../widgets/station_logo.dart';

/// Player em tela cheia: logo grande, música tocando e controles.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const PlayerScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LockService.locked,
      builder: (context, locked, child) => PopScope(canPop: !locked, child: child!),
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF110D0A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tocando agora',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: const [LockButton(), BluetoothButton(), SizedBox(width: 4)],
      ),
      body: const PlayerPanel(topPadding: 56),
    );
  }
}

/// Conteúdo do player. Em espaço largo fica deitado (logo à esquerda,
/// controles à direita); em espaço alto fica em pé.
/// Usado no player em tela cheia e na tela inicial dividida (carro/tablet).
class PlayerPanel extends StatelessWidget {
  final double topPadding;
  const PlayerPanel({super.key, this.topPadding = 0});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerListenable,
      builder: (context, _) {
        final s = radio.current.value;
        final tint = s == null ? const Color(0xFF3A2414) : StationColors.of(s);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(tint, Colors.black, 0.05)!,
                Color.lerp(tint, const Color(0xFF110D0A), 0.75)!,
                const Color(0xFF110D0A),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: LayoutBuilder(builder: (context, c) {
                if (s == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Toque numa rádio da lista para começar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  );
                }
                final wide = c.maxWidth > c.maxHeight * 1.15 && c.maxWidth >= 480;
                return wide ? _wide(context, c) : _tall(context, c);
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _logo(double size) {
    final s = radio.current.value!;
    final st = radio.status.value;
    return AnimatedScale(
      scale: st == RadioStatus.playing ? 1.0 : 0.92,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Hero(tag: 'current-logo', child: StationLogo(station: s, size: size)),
      ),
    );
  }

  Widget _info({required TextAlign align, required double nameSize}) {
    final s = radio.current.value!;
    final st = radio.status.value;
    final song = radio.songTitle.value;
    final msg = radio.message.value;
    final cross = align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        Text(
          s.name,
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            song ?? (s.genre ?? ''),
            key: ValueKey(song ?? ''),
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: nameSize * 0.62, color: Colors.white70, height: 1.3),
          ),
        ),
        const SizedBox(height: 10),
        StatusPill(status: st, text: statusTextOf(st, msg), large: true),
      ],
    );
  }

  Widget _controls(double playSize) {
    final st = radio.status.value;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Rádio anterior',
          iconSize: playSize * 0.56,
          onPressed: () => radio.skipToPrevious(),
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        SizedBox(width: playSize * 0.28),
        PlayButton(size: playSize, status: st),
        SizedBox(width: playSize * 0.28),
        IconButton(
          tooltip: 'Próxima rádio',
          iconSize: playSize * 0.56,
          onPressed: () => radio.skipToNext(),
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }

  /// Em pé (celular normal, tablet em pé).
  Widget _tall(BuildContext context, BoxConstraints c) {
    if (c.maxHeight < 600) {
      // Pouca altura (painel lateral, telas pequenas): tudo encolhe junto.
      final w = min(c.maxWidth, 420.0);
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: w,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _logo(min(w * 0.55, 200.0)),
                  const SizedBox(height: 18),
                  _info(align: TextAlign.center, nameSize: 22),
                  const SizedBox(height: 16),
                  _controls(64),
                  const SizedBox(height: 14),
                  const PlayerActionsRow(),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final logo = min(min(c.maxWidth * 0.68, c.maxHeight * 0.38), 360.0);
    final big = c.maxWidth >= 600;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              _logo(logo),
              const Spacer(),
              _info(align: TextAlign.center, nameSize: big ? 30 : 26),
              const SizedBox(height: 26),
              _controls(big ? 86 : 76),
              const SizedBox(height: 24),
              const PlayerActionsRow(),
            ],
          ),
        ),
      ),
    );
  }

  /// Deitado (central do carro, tablet deitado, celular deitado).
  Widget _wide(BuildContext context, BoxConstraints c) {
    final logo = min(min(c.maxHeight * 0.72, c.maxWidth * 0.40), 380.0);
    final compactH = c.maxHeight < 380;
    final playSize = compactH ? 60.0 : (c.maxHeight < 520 ? 70.0 : 84.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: compactH ? 8 : 20),
      child: Row(
        children: [
          Expanded(child: Center(child: _logo(logo))),
          const SizedBox(width: 24),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _info(align: TextAlign.center, nameSize: compactH ? 22 : 28),
                    SizedBox(height: compactH ? 12 : 24),
                    _controls(playSize),
                    SizedBox(height: compactH ? 10 : 22),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: const PlayerActionsRow(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
