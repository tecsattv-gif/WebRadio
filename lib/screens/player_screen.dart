import 'package:flutter/material.dart';

import '../main.dart';
import '../services/radio_handler.dart';
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
    return ListenableBuilder(
      listenable: playerListenable,
      builder: (context, _) {
        final s = radio.current.value;
        final st = radio.status.value;
        final song = radio.songTitle.value;
        final msg = radio.message.value;
        final tint = s == null ? const Color(0xFF3A2414) : StationColors.of(s);
        final size = MediaQuery.sizeOf(context);
        final logoSize = [size.width * 0.68, size.height * 0.36, 340.0]
            .reduce((a, b) => a < b ? a : b);

        return Scaffold(
          backgroundColor: const Color(0xFF110D0A),
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
          ),
          extendBodyBehindAppBar: true,
          body: AnimatedContainer(
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
              child: s == null
                  ? const Center(child: Text('Escolha uma rádio na lista.'))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                      child: Column(
                        children: [
                          const Spacer(),
                          AnimatedScale(
                            scale: st == RadioStatus.playing ? 1.0 : 0.92,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(logoSize * 0.26),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 40,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: Hero(
                                tag: 'current-logo',
                                child: StationLogo(station: s, size: logoSize),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            s.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 46,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: Text(
                                song ?? (s.genre ?? ''),
                                key: ValueKey(song ?? ''),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white70, height: 1.3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          StatusPill(status: st, text: statusTextOf(st, msg), large: true),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Rádio anterior',
                                iconSize: 44,
                                onPressed: () => radio.skipToPrevious(),
                                icon: const Icon(Icons.skip_previous_rounded),
                              ),
                              const SizedBox(width: 22),
                              PlayButton(size: 78, status: st),
                              const SizedBox(width: 22),
                              IconButton(
                                tooltip: 'Próxima rádio',
                                iconSize: 44,
                                onPressed: () => radio.skipToNext(),
                                icon: const Icon(Icons.skip_next_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          const PlayerActionsRow(),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
