import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../main.dart';
import '../models/station.dart';
import '../services/radio_handler.dart';
import '../widgets/now_playing_card.dart';
import '../widgets/station_logo.dart';
import '../services/update_service.dart';
import 'backup_screen.dart';
import 'recordings_screen.dart';
import 'suggested_screen.dart';
import 'sync_screen.dart';
import 'station_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Ao voltar para o app, pega as mudanças feitas em outro celular.
    _lifecycle = AppLifecycleListener(onResume: () => radio.sync.syncNow());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.checkOnStart(context);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radio_rounded, color: Color(0xFFFF8A1F)),
            SizedBox(width: 10),
            Text('WebRádio', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gravações',
            icon: const Icon(Icons.library_music_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordingsScreen()),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'suggested', child: Text('Rádios sugeridas')),
              PopupMenuItem(value: 'sync', child: Text('Sincronizar celulares')),
              PopupMenuItem(value: 'backup', child: Text('Backup e restauração')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'update', child: Text('Procurar atualização')),
              PopupMenuItem(value: 'about', child: Text('Sobre')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openStationEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Rádio'),
      ),
      body: ValueListenableBuilder<List<Station>>(
        valueListenable: radio.stations,
        builder: (context, list, _) {
          if (list.isEmpty) return const _EmptyState();
          return Column(
            children: [
              const NowPlayingCard(),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  onReorder: (a, b) => radio.reorder(a, b),
                  itemBuilder: (context, i) => _StationTile(
                    key: ValueKey(list[i].id),
                    station: list[i],
                    index: i,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    switch (value) {
      case 'suggested':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SuggestedScreen()));
      case 'sync':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SyncScreen()));
      case 'backup':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BackupScreen()));
      case 'update':
        await UpdateService.checkManually(context);
      case 'about':
        await _about(context);
    }
  }

  Future<void> _about(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'WebRádio',
      applicationVersion: 'Versão ${info.version}',
      applicationIcon: const Icon(Icons.radio_rounded, size: 40, color: Color(0xFFFF8A1F)),
      children: const [
        SizedBox(height: 8),
        Text('Criado por Luiz Alberto Cardoso'),
        Text('tecsattv@gmail.com'),
      ],
    );
  }
}

class _StationTile extends StatelessWidget {
  final Station station;
  final int index;

  const _StationTile({super.key, required this.station, required this.index});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([radio.current, radio.status]),
      builder: (context, _) {
        final isCurrent = radio.current.value?.id == station.id;
        final active = isCurrent && radio.status.value == RadioStatus.playing;
        final genre = station.genre?.trim() ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Material(
            color: isCurrent
                ? scheme.primary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
              leading: StationLogo(station: station, size: 48),
              title: Text(
                station.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                  color: isCurrent ? scheme.primary : null,
                ),
              ),
              subtitle: Text(
                genre.isNotEmpty ? genre : (Uri.tryParse(station.url)?.host ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active) Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        openStationEditor(context, station);
                      } else if (v == 'delete') {
                        confirmDeleteStation(context, station);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(4, 12, 12, 12),
                      child: Icon(Icons.drag_handle_rounded, color: Colors.white38),
                    ),
                  ),
                ],
              ),
              onTap: () {
                if (isCurrent && radio.isActive) {
                  radio.pause();
                } else {
                  radio.playStation(station);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radio_rounded, size: 88, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Sua lista está vazia',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toque em "+ Rádio" e cole o link do streaming da rádio que você quer ouvir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SuggestedScreen())),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Ver rádios sugeridas'),
              style: FilledButton.styleFrom(foregroundColor: Colors.black),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SyncScreen())),
              icon: const Icon(Icons.sync),
              label: const Text('Tenho um código de sincronização'),
            ),
          ],
        ),
      ),
    );
  }
}
