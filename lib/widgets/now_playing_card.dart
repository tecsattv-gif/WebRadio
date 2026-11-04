import 'package:flutter/material.dart';

import '../main.dart';
import '../services/radio_handler.dart';
import 'format.dart';
import 'station_logo.dart';

/// Cartão do topo: rádio atual, música tocando, play, timer e gravação.
class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        radio.current,
        radio.songTitle,
        radio.status,
        radio.message,
        radio.sleepRemaining,
        radio.recorder.state,
      ]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        final s = radio.current.value;
        final st = radio.status.value;
        final song = radio.songTitle.value;
        final msg = radio.message.value;
        final sleep = radio.sleepRemaining.value;
        final rec = radio.recorder.state.value;

        final connecting =
            st == RadioStatus.connecting || st == RadioStatus.reconnecting;

        String statusText = '';
        switch (st) {
          case RadioStatus.playing:
            statusText = 'AO VIVO';
          case RadioStatus.connecting:
            statusText = 'Conectando…';
          case RadioStatus.reconnecting:
            statusText = msg ?? 'Reconectando…';
          case RadioStatus.paused:
            statusText = 'Pausado';
          case RadioStatus.error:
            statusText = msg ?? 'Erro';
          case RadioStatus.idle:
            statusText = 'Parado';
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A2414), Color(0xFF1E1610)],
            ),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (s != null)
                    StationLogo(station: s, size: 76)
                  else
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.radio, size: 36, color: scheme.primary),
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
                          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song ?? (s == null ? 'Toque numa rádio da lista' : ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        if (s != null) _StatusPill(status: st, text: statusText),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Rádio anterior',
                    iconSize: 36,
                    onPressed: () => radio.skipToPrevious(),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (connecting)
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: scheme.primary,
                            ),
                          ),
                        Material(
                          color: scheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => radio.togglePlay(),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: Icon(
                                radio.isActive
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 40,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'Próxima rádio',
                    iconSize: 36,
                    onPressed: () => radio.skipToNext(),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ActionChip(
                      icon: Icons.bedtime_outlined,
                      label: sleep == null ? 'Timer' : 'Desliga em ${formatDuration(sleep)}',
                      active: sleep != null,
                      activeColor: scheme.primary,
                      onTap: () => showSleepTimerSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionChip(
                      icon: rec != null ? Icons.stop_rounded : Icons.fiber_manual_record,
                      label: rec != null
                          ? '${formatDuration(rec.elapsed)} · ${formatBytes(rec.bytes)}'
                          : 'Gravar',
                      active: rec != null,
                      activeColor: Colors.redAccent,
                      iconColor: rec == null ? Colors.redAccent : null,
                      onTap: () => _toggleRecording(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleRecording(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final wasRecording = radio.recorder.isRecording;
    final err = await radio.toggleRecording();
    messenger.hideCurrentSnackBar();
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
    } else if (wasRecording) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Gravação salva. Veja no botão Gravações, lá em cima.')));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Gravando…')));
    }
  }
}

class _StatusPill extends StatelessWidget {
  final RadioStatus status;
  final String text;
  const _StatusPill({required this.status, required this.text});

  @override
  Widget build(BuildContext context) {
    final live = status == RadioStatus.playing;
    final error = status == RadioStatus.error;
    final color = live
        ? Colors.redAccent
        : error
            ? Colors.orangeAccent
            : Colors.white54;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
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
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ActionChip({
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
        ? activeColor.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.06);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: active ? activeColor : (iconColor ?? Colors.white70)),
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
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
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
