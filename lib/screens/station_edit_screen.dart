import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/station.dart';
import '../services/logo_converter.dart';
import '../services/stream_resolver.dart';
import '../widgets/station_logo.dart';

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
  String? _logoData;
  String? _convertedFrom;
  bool _converting = false;
  String? _logoMsg;

  bool get _isNew => widget.station == null;

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _name = TextEditingController(text: s?.name ?? '');
    _url = TextEditingController(text: s?.url ?? '');
    _genre = TextEditingController(text: s?.genre ?? '');
    _logo = TextEditingController(text: s?.logoUrl ?? '');
    _logoData = s?.logoData;
    if ((_logoData ?? '').isNotEmpty) _convertedFrom = s?.logoUrl?.trim();
  }

  /// Converte o link do logo (se mudou). Devolve true se está tudo certo.
  Future<bool> _convertLink() async {
    final link = _logo.text.trim();
    if (link.isEmpty || link == _convertedFrom) return true;
    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      setState(() => _logoMsg = 'O link do logo precisa começar com http:// ou https://');
      return false;
    }
    setState(() {
      _converting = true;
      _logoMsg = null;
    });
    try {
      final data = await LogoConverter.fromUrl(link);
      if (!mounted) return true;
      setState(() {
        _logoData = data;
        _convertedFrom = link;
        _logoMsg = 'Logo convertido.';
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _logoMsg = e is LogoError ? e.message : 'Não consegui converter a imagem.');
      return false;
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    } catch (_) {
      setState(() => _logoMsg = 'Não consegui abrir a galeria.');
      return;
    }
    if (file == null) return;
    setState(() {
      _converting = true;
      _logoMsg = null;
    });
    try {
      final data = await LogoConverter.fromBytes(await file.readAsBytes());
      if (!mounted) return;
      setState(() {
        _logoData = data;
        _logo.clear();
        _convertedFrom = null;
        _logoMsg = 'Logo convertido.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _logoMsg = e is LogoError ? e.message : 'Não consegui converter a imagem.');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _removeLogo() {
    setState(() {
      _logoData = null;
      _convertedFrom = null;
      _logo.clear();
      _logoMsg = null;
    });
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
    if (_converting) return;
    final ok = await _convertLink();
    if (!mounted) return;
    // Link novo que não converteu: fica só o link (o app tenta mostrar direto).
    if (!ok) _logoData = null;
    final station = Station(
      id: widget.station?.id ?? Station.newId(),
      name: _name.text.trim(),
      url: _url.text.trim(),
      genre: _genre.text.trim().isEmpty ? null : _genre.text.trim(),
      logoUrl: _logo.text.trim().isEmpty ? null : _logo.text.trim(),
      logoData: (_logoData ?? '').isEmpty ? null : _logoData,
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
              const Text('Logo (opcional)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _converting
                      ? const SizedBox(
                          width: 72,
                          height: 72,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : StationLogo(
                          station: Station(
                            id: 'preview',
                            name: _name.text.trim().isEmpty ? '?' : _name.text.trim(),
                            url: '',
                            logoData: _logoData,
                          ),
                          size: 72,
                        ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _converting ? null : _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Escolher da galeria'),
                        ),
                        if ((_logoData ?? '').isNotEmpty)
                          TextButton.icon(
                            onPressed: _converting ? null : _removeLogo,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover logo'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _logo,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onFieldSubmitted: (_) => _convertLink(),
                decoration: InputDecoration(
                  labelText: 'Ou cole o link da imagem',
                  hintText: 'https://…/logo.png',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.image_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Converter',
                    icon: const Icon(Icons.auto_fix_high),
                    onPressed: _converting ? null : _convertLink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _logoMsg ??
                    'O app converte a imagem sozinho num logo pequeno, que vai junto na sincronização.',
                style: TextStyle(
                  fontSize: 12,
                  color: _logoMsg == null
                      ? Colors.white60
                      : (_logoMsg == 'Logo convertido.'
                          ? Colors.greenAccent
                          : Colors.orangeAccent),
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
