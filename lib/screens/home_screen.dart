import 'package:flutter/material.dart';

import '../main.dart';
import '../models/station.dart';
import '../services/radio_handler.dart';
import '../widgets/bluetooth_button.dart';
import '../widgets/equalizer.dart';
import '../widgets/genre_chips.dart';
import '../widgets/now_playing_card.dart';
import '../widgets/station_logo.dart';
import '../services/update_service.dart';
import 'settings_screen.dart';
import 'player_screen.dart';
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
  String? _genre; // filtro de gênero (null = todas)

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
          const BluetoothButton(),
          IconButton(
            tooltip: 'Gravações',
            icon: const Icon(Icons.library_music_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => SettingsScreen.open(context),
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
          final listParts = <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    const Text('Minhas rádios',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${list.length}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ),
                  ],
                ),
              ),
              GenreChips(
                stations: list,
                selected: _genre,
                onSelected: (g) => setState(() => _genre = g),
              ),
              Expanded(
                child: Builder(builder: (context) {
                  final g = _genre;
                  // Gênero escolhido sumiu da lista: volta para "Todas".
                  if (g != null && !list.any((s) => genreKey(s) == g)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _genre = null);
                    });
                  }
                  if (g == null) {
                    return ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.only(top: 4, bottom: 100),
                      itemCount: list.length,
                      onReorder: (a, b) => radio.reorder(a, b),
                      itemBuilder: (context, i) => _StationTile(
                        key: ValueKey(list[i].id),
                        station: list[i],
                        index: i,
                      ),
                    );
                  }
                  final filtered = list.where((s) => genreKey(s) == g).toList();
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _StationTile(
                      key: ValueKey(filtered[i].id),
                      station: filtered[i],
                      index: i,
                      reorderable: false,
                    ),
                  );
                }),
              ),
          ];
          return LayoutBuilder(builder: (context, c) {
            final twoPane = c.maxWidth >= 840 || (c.maxWidth > c.maxHeight && c.maxWidth >= 600);
            if (twoPane) {
              // Central do carro, tablet ou celular deitado: player à esquerda, lista à direita.
              final paneW = (c.maxWidth * 0.44).clamp(300.0, 560.0);
              return Row(
                children: [
                  SizedBox(width: paneW, child: const PlayerPanel()),
                  Container(width: 1, color: Colors.white.withValues(alpha: 0.06)),
                  Expanded(child: Column(children: listParts)),
                ],
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(children: [const NowPlayingCard(), ...listParts]),
              ),
            );
          });
        },
      ),
    );
  }

}

class _StationTile extends StatelessWidget {
  final Station station;
  final int index;
  final bool reorderable;

  const _StationTile({
    super.key,
    required this.station,
    required this.index,
    this.reorderable = true,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Material(
            color: isCurrent
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.035),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isCurrent
                    ? scheme.primary.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
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
                  if (active) Equalizer(active: true, color: scheme.primary, size: 18),
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
                  if (reorderable)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(4, 12, 12, 12),
                        child: Icon(Icons.drag_handle_rounded, color: Colors.white38),
                      ),
                    )
                  else
                    const SizedBox(width: 8),
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
              onPressed: () => SettingsScreen.open(context),
              icon: const Icon(Icons.travel_explore),
              label: const Text('Buscar rádios'),
              style: FilledButton.styleFrom(foregroundColor: Colors.black),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SuggestedScreen())),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Ver rádios sugeridas'),
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
