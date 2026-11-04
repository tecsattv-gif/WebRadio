import 'package:flutter/material.dart';

import '../main.dart';
import '../models/station.dart';
import '../services/firebase_api.dart';
import '../widgets/station_logo.dart';

/// Rádios sugeridas (lista pública publicada pelo administrador).
class SuggestedScreen extends StatefulWidget {
  const SuggestedScreen({super.key});

  @override
  State<SuggestedScreen> createState() => _SuggestedScreenState();
}

class _SuggestedScreenState extends State<SuggestedScreen> {
  List<Station>? _items;
  String? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await FirebaseApi.fetchPublic();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is FirebaseError ? e.message : 'Sem conexão com a internet.';
        _items ??= [];
      });
    }
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  bool _inMyList(Station s) =>
      radio.stations.value.any((m) => m.url.trim() == s.url.trim());

  Future<void> _add(Station s) async {
    if (_inMyList(s)) {
      _snack('Já está na sua lista.');
      return;
    }
    await radio.addStation(s.copyWith(id: Station.newId()));
    if (!mounted) return;
    setState(() {});
    _snack('"${s.name}" adicionada à sua lista.');
  }

  Future<void> _adminLogin() async {
    final ctrl = TextEditingController();
    final pass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar como administrador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(FirebaseApi.adminEmail, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Entrar')),
        ],
      ),
    );
    if (pass == null || pass.isEmpty) return;
    final err = await FirebaseApi.adminLogin(pass);
    if (!mounted) return;
    _snack(err ?? 'Pronto: você pode publicar e remover rádios sugeridas.');
  }

  Future<void> _publishFromMyList() async {
    final published = (_items ?? []).map((s) => s.url.trim()).toSet();
    final candidates =
        radio.stations.value.where((s) => !published.contains(s.url.trim())).toList();
    if (candidates.isEmpty) {
      _snack('Todas as rádios da sua lista já estão publicadas.');
      return;
    }
    final chosen = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Publicar da minha lista'),
          contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in candidates)
                  CheckboxListTile(
                    value: chosen.contains(s.id),
                    title: Text(s.name),
                    subtitle: (s.genre ?? '').isEmpty ? null : Text(s.genre!),
                    onChanged: (v) => setD(() {
                      if (v == true) {
                        chosen.add(s.id);
                      } else {
                        chosen.remove(s.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || chosen.isEmpty) return;
    var count = 0;
    try {
      for (final s in candidates.where((s) => chosen.contains(s.id))) {
        await FirebaseApi.publish(s);
        count++;
      }
      _snack('$count rádio(s) publicada(s).');
    } catch (e) {
      _snack(e is FirebaseError ? e.message : 'Sem conexão com a internet.');
    }
    await _load();
  }

  Future<void> _unpublish(Station s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover das sugeridas?'),
        content: Text('"${s.name}" deixa de aparecer para todos os usuários.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseApi.unpublish(s.id);
      _snack('Removida das sugeridas.');
    } catch (e) {
      _snack(e is FirebaseError ? e.message : 'Sem conexão com a internet.');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: FirebaseApi.isAdmin,
      builder: (context, admin, _) {
        final items = (_items ?? [])
            .where((s) =>
                _filter.isEmpty ||
                s.name.toLowerCase().contains(_filter) ||
                (s.genre ?? '').toLowerCase().contains(_filter))
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Rádios sugeridas'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'login') _adminLogin();
                  if (v == 'logout') FirebaseApi.adminLogout();
                },
                itemBuilder: (_) => [
                  if (!admin)
                    const PopupMenuItem(value: 'login', child: Text('Entrar como administrador'))
                  else
                    const PopupMenuItem(value: 'logout', child: Text('Sair do modo administrador')),
                ],
              ),
            ],
          ),
          floatingActionButton: admin
              ? FloatingActionButton.extended(
                  onPressed: _publishFromMyList,
                  icon: const Icon(Icons.publish),
                  label: const Text('Publicar'),
                )
              : null,
          body: _items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextField(
                          onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Buscar por nome ou gênero',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (admin)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(
                            'Modo administrador: toque em Publicar para enviar rádios da sua lista. '
                            'Segure uma rádio para removê-la.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.orangeAccent)),
                        )
                      else if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Nenhuma rádio sugerida por enquanto.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      for (final s in items)
                        ListTile(
                          leading: StationLogo(station: s, size: 44),
                          title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            (s.genre ?? '').isNotEmpty
                                ? s.genre!
                                : (Uri.tryParse(s.url)?.host ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _inMyList(s)
                              ? Icon(Icons.check_circle, color: scheme.primary)
                              : IconButton(
                                  tooltip: 'Adicionar à minha lista',
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _add(s),
                                ),
                          onTap: () => _add(s),
                          onLongPress: admin ? () => _unpublish(s) : null,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
