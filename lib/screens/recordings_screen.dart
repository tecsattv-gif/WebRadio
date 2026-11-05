import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../services/recorder.dart';
import '../widgets/format.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final AudioPlayer _player = AudioPlayer();
  List<File> _files = [];
  bool _loading = true;
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _load();
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        _player.stop();
        setState(() => _playingPath = null);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dir = await Recorder.folder();
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  String _name(File f) => f.path.split('/').last;

  Future<void> _togglePlay(File f) async {
    if (_playingPath == f.path) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      setState(() {});
      return;
    }
    if (radio.isActive) await radio.pause();
    try {
      await _player.setFilePath(f.path);
      setState(() => _playingPath = f.path);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível tocar este arquivo.')),
      );
    }
  }

  Future<void> _share(File f) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
  }

  Future<void> _delete(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar gravação?'),
        content: Text(_name(f)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    if (_playingPath == f.path) {
      await _player.stop();
      _playingPath = null;
    }
    try {
      await f.delete();
    } catch (_) {}
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Gravações')),
      bottomNavigationBar: _playingPath == null ? null : _PlayerBar(player: _player, title: _name(File(_playingPath!))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<RecordingInfo?>(
              valueListenable: radio.recorder.state,
              builder: (context, rec, _) {
                if (_files.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nenhuma gravação ainda.\nUse o botão "Gravar" enquanto ouve uma rádio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.only(top: 8, bottom: 24 + MediaQuery.paddingOf(context).bottom),
                    itemCount: _files.length,
                    itemBuilder: (context, i) {
                      final f = _files[i];
                      final recordingNow = rec?.path == f.path;
                      final isPlaying = _playingPath == f.path;
                      int size = 0;
                      DateTime? date;
                      try {
                        size = f.lengthSync();
                        date = f.lastModifiedSync();
                      } catch (_) {}
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: recordingNow
                              ? Colors.redAccent.withValues(alpha: 0.25)
                              : scheme.primary.withValues(alpha: 0.18),
                          child: Icon(
                            recordingNow
                                ? Icons.fiber_manual_record
                                : (isPlaying ? Icons.graphic_eq : Icons.audiotrack),
                            color: recordingNow ? Colors.redAccent : scheme.primary,
                          ),
                        ),
                        title: Text(_name(f), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(recordingNow
                            ? 'Gravando agora…'
                            : '${date != null ? formatDate(date) : ''} · ${formatBytes(size)}'),
                        onTap: recordingNow ? null : () => _togglePlay(f),
                        trailing: recordingNow
                            ? null
                            : PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'share') _share(f);
                                  if (v == 'delete') _delete(f);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'share', child: Text('Compartilhar / salvar')),
                                  PopupMenuItem(value: 'delete', child: Text('Apagar')),
                                ],
                              ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  final AudioPlayer player;
  final String title;
  const _PlayerBar({required this.player, required this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
        color: const Color(0xFF241A12),
        child: StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snap) {
            final pos = snap.data ?? Duration.zero;
            final dur = player.duration ?? Duration.zero;
            final max = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
            final value = pos.inMilliseconds.clamp(0, max.toInt()).toDouble();
            return Row(
              children: [
                StreamBuilder<bool>(
                  stream: player.playingStream,
                  builder: (context, p) => IconButton(
                    iconSize: 32,
                    icon: Icon((p.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    onPressed: () => (p.data ?? false) ? player.pause() : player.play(),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Slider(
                        value: value,
                        max: max,
                        onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                      ),
                    ],
                  ),
                ),
                Text('${formatDuration(pos)} / ${formatDuration(dur)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            );
          },
        ),
      ),
    );
  }
}
