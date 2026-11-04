import 'package:flutter/material.dart';

import '../main.dart';
import '../models/station.dart';
import '../services/stream_resolver.dart';

Future<void> openStationEditor(BuildContext context, Station? station) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => StationEditScreen(station: station)),
  );
}

Future<void> confirmDeleteStation(BuildContext context, Station station) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Excluir rádio?'),
      content: Text('"${station.name}" vai sair da sua lista.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
      ],
    ),
  );
  if (ok == true) await radio.removeStation(station.id);
}

class StationEditScreen extends StatefulWidget {
  final Station? station;
  const StationEditScreen({super.key, this.station});

  @override
  State<StationEditScreen> createState() => _StationEditScreenState();
}

class _StationEditScreenState extends State<StationEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _genre;
  late final TextEditingController _logo;
  bool _testing = false;
  String? _testResult;

  bool get _isNew => widget.station == null;

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _name = TextEditingController(text: s?.name ?? '');
    _url = TextEditingController(text: s?.url ?? '');
    _genre = TextEditingController(text: s?.genre ?? '');
    _logo = TextEditingController(text: s?.logoUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _genre.dispose();
    _logo.dispose();
    super.dispose();
  }

  String? _validateUrl(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Cole o link do streaming';
    if (!t.startsWith('http://') && !t.startsWith('https://')) {
      return 'O link precisa começar com http:// ou https://';
    }
    return null;
  }

  Future<void> _test() async {
    if (_validateUrl(_url.text) != null) {
      _form.currentState?.validate();
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final r = await checkStream(_url.text.trim());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = r;
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final station = Station(
      id: widget.station?.id ?? Station.newId(),
      name: _name.text.trim(),
      url: _url.text.trim(),
      genre: _genre.text.trim().isEmpty ? null : _genre.text.trim(),
      logoUrl: _logo.text.trim().isEmpty ? null : _logo.text.trim(),
    );
    if (_isNew) {
      await radio.addStation(station);
    } else {
      await radio.updateStation(station);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nova rádio' : 'Editar rádio'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final nav = Navigator.of(context);
                await confirmDeleteStation(context, widget.station!);
                if (!radio.stations.value.any((s) => s.id == widget.station!.id)) {
                  nav.pop();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome da rádio *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.radio),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Dê um nome para a rádio' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Link do streaming *',
                  hintText: 'http://servidor:porta/stream',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                validator: _validateUrl,
              ),
              const SizedBox(height: 6),
              const Text(
                'Aceita link direto de áudio (MP3, AAC, OGG), HLS (.m3u8) e playlists .pls / .m3u.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Testar link'),
                  ),
                  const SizedBox(width: 12),
                  if (_testResult != null)
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _testResult!.startsWith('Link OK')
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _genre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Gênero / cidade (opcional)',
                  hintText: 'Sertanejo, Notícias, São Paulo…',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _logo,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Link do logo (opcional)',
                  hintText: 'https://…/logo.png',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Salvar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
