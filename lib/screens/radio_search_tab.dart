import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';

import '../main.dart';
import '../models/station.dart';
import '../services/logo_converter.dart';
import '../services/radio_browser.dart';
import '../widgets/equalizer.dart';
import '../widgets/format.dart';

/// Aba "Buscar rádios": procura no Radio Browser, ouve antes e adiciona.
class RadioSearchTab extends StatefulWidget {
  const RadioSearchTab({super.key});

  @override
  State<RadioSearchTab> createState() => _RadioSearchTabState();
}

class _RadioSearchTabState extends State<RadioSearchTab>
    with AutomaticKeepAliveClientMixin {
  static const _countries = <String, String>{
    'BR': 'Brasil',
    'PT': 'Portugal',
    'US': 'Estados Unidos',
    'ES': 'Espanha',
    'IT': 'Itália',
    'FR': 'França',
    'DE': 'Alemanha',
    'AR': 'Argentina',
    'PY': 'Paraguai',
    'UY': 'Uruguai',
    'MX': 'México',
    '': 'Todos os países',
  };

  static const _styles = <String, String>{
    'Sertanejo': 'sertanejo',
    'Sertanejo raiz': 'sertanejo raiz',
    'Gospel': 'gospel',
    'Notícias': 'news',
    'Forró': 'forro',
    'Pagode': 'pagode',
    'MPB': 'mpb',
    'Rock': 'rock',
    'Pop': 'pop',
    'Flashback': 'oldies',
    'Eletrônica': 'electronic',
    'Esportes': 'sports',
    'Clássica': 'classical',
    'Jazz': 'jazz',
  };

  final _query = TextEditingController();
  final AudioPlayer _preview = AudioPlayer();
  String _country = 'BR';
  String? _style;
  List<FoundStation>? _results;
  bool _loading = false;
  String? _error;
  String? _previewUrl;
  bool _previewLoading = false;
  final Set<String> _adding = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _preview.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _previewLoading = s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering;
      });
    });
  }

  @override
  void dispose() {
    _preview.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    if (_query.text.trim().isEmpty && _style == null) {
      setState(() => _error = 'Digite um nome ou escolha um estilo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await RadioBrowser.search(
        name: _query.text,
        tag: _style == null ? '' : _styles[_style]!,
        countryCode: _country,
      );
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não consegui buscar agora. Confira a internet e tente de novo.';
      });
    }
  }

  /// "Perto de mim" (1.8.7): rádios da sua região pelo GPS.
  Future<void> _nearby() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Ligue a localização (GPS) do celular.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Sem permissão de localização, não dá para achar as rádios perto de você.';
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 20)));
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) throw 'Não consegui pegar a sua posição. Tente de novo.';
      final list = await RadioBrowser.nearby(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _style = null;
        _results = list;
        _loading = false;
        if (list.isEmpty) {
          _error = 'Nenhuma rádio da sua região no diretório. '
              'Tente buscar pelo nome da cidade.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is String
            ? e
            : 'Não consegui buscar agora. Confira a internet e tente de novo.';
      });
    }
  }

  bool _inMyList(FoundStation f) =>
      radio.stations.value.any((s) => s.url.trim() == f.url.trim());

  Future<void> _togglePreview(FoundStation f) async {
    if (_previewUrl == f.url) {
      await _preview.stop();
      setState(() => _previewUrl = null);
      return;
    }
    if (radio.isActive) await radio.pause();
    setState(() => _previewUrl = f.url);
    try {
      await _preview.setUrl(f.url);
      _preview.play();
      RadioBrowser.countClick(f.uuid);
    } catch (_) {
      if (!mounted) return;
      setState(() => _previewUrl = null);
      _snack('Esta rádio não tocou. Pode estar fora do ar.');
    }
  }

  String _genreFor(FoundStation f) {
    if (_style != null) return _style!;
    if (f.tags.isEmpty) return '';
    final t = f.tags.first;
    return t[0].toUpperCase() + t.substring(1);
  }

  Future<void> _add(FoundStation f) async {
    if (_inMyList(f)) {
      _snack('Já está na sua lista.');
      return;
    }
    setState(() => _adding.add(f.url));
    String? logoData;
    if (f.favicon.startsWith('http')) {
      try {
        logoData = await LogoConverter.fromUrl(f.favicon);
      } catch (_) {
        logoData = null; // sem logo, o app usa as iniciais
      }
    }
    final genre = _genreFor(f);
    await radio.addStation(Station(
      id: Station.newId(),
      name: f.name,
      url: f.url,
      genre: genre.isEmpty ? null : genre,
      logoUrl: f.favicon.isEmpty ? null : f.favicon,
      logoData: logoData,
    ));
    if (!mounted) return;
    setState(() => _adding.remove(f.url));
    _snack('"${f.name}" adicionada à sua lista.');
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final gutter = sideGutter(MediaQuery.sizeOf(context).width, maxContent: 760);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
          sliver: SliverList.list(children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Nome da rádio',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _query.clear()),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.black,
                    minimumSize: const Size(56, 48),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _country,
              isDense: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.public),
                isDense: true,
              ),
              items: [
                for (final e in _countries.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                setState(() => _country = v ?? 'BR');
                if (_results != null) _search();
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loading ? null : _nearby,
              icon: const Icon(Icons.my_location),
              label: const Text('Rádios perto de mim (FM local)'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder()),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final st in _styles.keys)
                  ChoiceChip(
                    label: Text(st),
                    selected: _style == st,
                    showCheckmark: false,
                    selectedColor: scheme.primary,
                    labelStyle: TextStyle(
                      color: _style == st ? Colors.black : Colors.white,
                      fontWeight: _style == st ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    shape: const StadiumBorder(),
                    onSelected: (_) {
                      setState(() => _style = _style == st ? null : st);
                      _search();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.orangeAccent)),
              )
            else if (_results == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Digite o nome de uma rádio, toque num estilo ou em '
                  '"Rádios perto de mim".\n'
                  'Toque no ▶ para ouvir antes e no + para adicionar à sua lista.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
              )
            else if (_results!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Nenhuma rádio encontrada. Tente outro nome ou "Todos os países".',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
              ),
          ]),
        ),
        if (_results != null && _results!.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter - 4, 0, gutter - 4, 24 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverList.builder(
              itemCount: _results!.length,
              itemBuilder: (context, i) => _tile(_results![i], scheme),
            ),
          ),
      ],
    );
  }

  Widget _tile(FoundStation f, ColorScheme scheme) {
    final previewing = _previewUrl == f.url;
    final inList = _inMyList(f);
    final adding = _adding.contains(f.url);
    Widget logo = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.radio, color: Colors.white38),
    );
    if (f.favicon.startsWith('http')) {
      logo = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          color: Colors.white,
          child: Image.network(
            f.favicon,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF2A211A),
              child: const Icon(Icons.radio, color: Colors.white38),
            ),
          ),
        ),
      );
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: logo,
      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: previewing ? FontWeight.w800 : FontWeight.w600,
              color: previewing ? scheme.primary : null)),
      subtitle: Text(f.details, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: previewing ? 'Parar' : 'Ouvir',
            onPressed: () => _togglePreview(f),
            icon: previewing
                ? (_previewLoading
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Equalizer(active: true, color: scheme.primary, size: 20))
                : const Icon(Icons.play_circle_outline),
          ),
          if (adding)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: inList ? 'Já está na lista' : 'Adicionar',
              onPressed: inList ? null : () => _add(f),
              icon: Icon(inList ? Icons.check_circle : Icons.add_circle_outline,
                  color: inList ? scheme.primary : null),
            ),
        ],
      ),
      onTap: () => _togglePreview(f),
    );
  }
}
