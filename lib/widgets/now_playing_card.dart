import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/player_screen.dart';
import '../services/radio_handler.dart';
import 'equalizer.dart';
import 'format.dart';
import 'station_colors.dart';
import 'station_logo.dart';

const Color kAccent = Color(0xFFFF8A1F);

/// Texto curto do estado da rádio.
String statusTextOf(RadioStatus st, String? msg) {
  switch (st) {
    case RadioStatus.playing:
      return 'AO VIVO';
    case RadioStatus.connecting:
      return 'Conectando…';
    case RadioStatus.reconnecting:
      return msg ?? 'Reconectando…';
    case RadioStatus.paused:
      return 'Pausado';
    case RadioStatus.error:
      return msg ?? 'Erro';
    case RadioStatus.idle:
      return 'Parado';
  }
}

Future<void> toggleRecordingWithSnack(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final wasRecording = radio.recorder.isRecording;
  final err = await radio.toggleRecording();
  messenger.hideCurrentSnackBar();
  if (err != null) {
    messenger.showSnackBar(SnackBar(content: Text(err)));
  } else if (wasRecording) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Gravação salva. Veja em Gravações (ícone no topo da tela inicial).')));
  } else {
    messenger.showSnackBar(const SnackBar(content: Text('Gravando…')));
  }
}

Listenable get playerListenable => Listenable.merge([
      radio.current,
      radio.songTitle,
      radio.status,
      radio.message,
      radio.sleepRemaining,
      radio.recorder.state,
      StationColors.version,
    ]);

/// Cartão do topo: rádio atual, música tocando, play, timer e gravação.
/// Tocar no cartão abre o player em tela cheia.
class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerListenable,
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        final s = radio.current.value;
        final st = radio.status.value;
        final song = radio.songTitle.value;
        final msg = radio.message.value;
        final tint = s == null ? const Color(0xFF3A2414) : StationColors.of(s);
        final live = st == RadioStatus.playing;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: s == null
                  ? null
                  : () => Navigator.push(context, PlayerScreen.route()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(tint, Colors.black, 0.05)!,
                      Color.lerp(tint, const Color(0xFF110D0A), 0.72)!,
                    ],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: live ? 0.45 : 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Hero(
                          tag: 'current-logo',
                          child: s != null
                              ? StationLogo(station: s, size: 72)
                              : Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(19),
                                  ),
                                  child: const Icon(Icons.radio_rounded, size: 34, color: kAccent),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s?.name ?? 'Escolha uma rádio',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800, letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 3),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: Text(
                                  song ?? (s == null ? 'Toque numa rádio da lista' : (s.genre ?? '')),
                                  key: ValueKey(song ?? ''),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium?.copyWith(color: Colors.white70, height: 1.25),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (s != null) StatusPill(status: st, text: statusTextOf(st, msg)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        PlayButton(size: 58, status: st),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const PlayerActionsRow(compact: true),
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

/// Botão redondo de play/pausa com anel de "conectando".
class PlayButton extends StatelessWidget {
  final double size;
  final RadioStatus status;
  const PlayButton({super.key, required this.size, required this.status});

  @override
  Widget build(BuildContext context) {
    final connecting =
        status == RadioStatus.connecting || status == RadioStatus.reconnecting;
    return SizedBox(
      width: size + 10,
      height: size + 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (connecting)
            SizedBox(
              width: size + 10,
              height: size + 10,
              child: const CircularProgressIndicator(strokeWidth: 2.5, color: kAccent),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kAccent.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: kAccent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => radio.togglePlay(),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Icon(
                      radio.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      key: ValueKey(radio.isActive),
                      size: size * 0.6,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha com Timer e Gravar (usada no cartão e no player em tela cheia).
class PlayerActionsRow extends StatelessWidget {
  final bool compact;
  const PlayerActionsRow({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([radio.sleepRemaining, radio.recorder.state]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final sleep = radio.sleepRemaining.value;
    final rec = radio.recorder.state.value;
    return Row(
      children: [
        if (compact) ...[
          _RoundIcon(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Rádio anterior',
            onTap: () => radio.skipToPrevious(),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: ActionChipButton(
            icon: Icons.bedtime_outlined,
            label: sleep == null ? 'Timer' : formatDuration(sleep),
            active: sleep != null,
            activeColor: kAccent,
            onTap: () => showSleepTimerSheet(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionChipButton(
            icon: rec != null ? Icons.stop_rounded : Icons.fiber_manual_record,
            label: rec != null
                ? '${formatDuration(rec.elapsed)} · ${formatBytes(rec.bytes)}'
                : 'Gravar',
            active: rec != null,
            activeColor: Colors.redAccent,
            iconColor: rec == null ? Colors.redAccent : null,
            onTap: () => toggleRecordingWithSnack(context),
          ),
        ),
        if (compact) ...[
          const SizedBox(width: 8),
          _RoundIcon(
            icon: Icons.skip_next_rounded,
            tooltip: 'Próxima rádio',
            onTap: () => radio.skipToNext(),
          ),
        ],
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 24),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final RadioStatus status;
  final String text;
  final bool large;
  const StatusPill({super.key, required this.status, required this.text, this.large = false});

  @override
  Widget build(BuildContext context) {
    final live = status == RadioStatus.playing;
    final error = status == RadioStatus.error;
    final color = live
        ? const Color(0xFFFF5252)
        : error
            ? Colors.orangeAccent
            : Colors.white60;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: live ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            Equalizer(active: true, color: color, size: large ? 16 : 12)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: live ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: live ? 1.2 : 0,
                fontSize: large ? 14 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const ActionChipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? activeColor.withValues(alpha: 0.24)
        : Colors.white.withValues(alpha: 0.08);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: active ? activeColor : (iconColor ?? Colors.white70)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Janela para escolher em quanto tempo a rádio desliga.
Future<void> showSleepTimerSheet(BuildContext context) async {
  const options = [15, 30, 45, 60, 90, 120];
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final active = radio.sleepRemaining.value != null;
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Desligar a rádio em…',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in options)
                      ActionChip(
                        label: Text(m < 60
                            ? '$m min'
                            : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min')),
                        onPressed: () {
                          radio.startSleepTimer(Duration(minutes: m));
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.edit, size: 18),
                      label: const Text('Outro'),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        final m = await _askMinutes(context);
                        if (m != null && m > 0) {
                          radio.startSleepTimer(Duration(minutes: m));
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (active)
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined),
                  title: const Text('Cancelar o timer'),
                  onTap: () {
                    radio.cancelSleepTimer();
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

Future<int?> _askMinutes(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Quantos minutos?'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(suffixText: 'min'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
