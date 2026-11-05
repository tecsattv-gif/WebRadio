import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/station.dart';
import '../services/station_store.dart';
import '../widgets/format.dart';

/// Backup e restauração da lista de rádios (com os logos).
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  static const String fileName = 'webradio_backup.json';

  void _snack(BuildContext context, String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  Uint8List _backupBytes() =>
      Uint8List.fromList(utf8.encode(StationStore.exportJson(radio.stations.value)));

  bool _checkNotEmpty(BuildContext context) {
    if (radio.stations.value.isEmpty) {
      _snack(context, 'Sua lista está vazia: não há o que salvar.');
      return false;
    }
    return true;
  }

  Future<void> _saveOnPhone(BuildContext context) async {
    if (!_checkNotEmpty(context)) return;
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar backup',
        fileName: fileName,
        bytes: _backupBytes(),
      );
      if (!context.mounted) return;
      if (path != null) {
        _snack(context, 'Backup salvo (${radio.stations.value.length} rádios).');
      }
    } catch (_) {
      if (context.mounted) _snack(context, 'Não consegui salvar o backup.');
    }
  }

  Future<void> _share(BuildContext context) async {
    if (!_checkNotEmpty(context)) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(_backupBytes()); // substitui o anterior
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Backup WebRádio',
    ));
  }

  Future<void> _restore(BuildContext context) async {
    final FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    } catch (_) {
      if (context.mounted) _snack(context, 'Não consegui abrir os arquivos.');
      return;
    }
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    Uint8List? bytes = f.bytes;
    if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
    if (bytes == null) return;
    final text = utf8.decode(bytes, allowMalformed: true);
    final list = StationStore.parseImport(text);
    if (!context.mounted) return;
    if (list.isEmpty) {
      _snack(context, 'Esse arquivo não é um backup do WebRádio.');
      return;
    }
    await _apply(context, list);
  }

  Future<void> _apply(BuildContext context, List<Station> list) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${list.length} rádio(s) encontrada(s)'),
        content: const Text(
            'Substituir a lista atual pelo backup, ou só juntar as rádios que faltam?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'merge'), child: const Text('Juntar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('Substituir')),
        ],
      ),
    );
    if (mode == null) return;
    if (mode == 'replace') {
      await radio.replaceStations(list);
      if (context.mounted) _snack(context, 'Backup restaurado: ${list.length} rádio(s).');
    } else {
      final added = await radio.importStations(list);
      if (context.mounted) {
        _snack(context, added == 0 ? 'Todas já estavam na lista.' : '$added rádio(s) adicionada(s).');
      }
    }
  }

  Future<void> _importText(BuildContext context) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar links'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Uma rádio por linha:\nNome | http://link-da-radio',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Rádio Exemplo | http://...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Importar')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    final list = StationStore.parseImport(text);
    if (list.isEmpty) {
      _snack(context, 'Não encontrei nenhum link de rádio no texto.');
      return;
    }
    final added = await radio.importStations(list);
    if (context.mounted) {
      _snack(context, added == 0 ? 'Essas rádios já estão na lista.' : '$added rádio(s) adicionada(s).');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup e restauração')),
      body: ListView(
        padding: EdgeInsets.symmetric(
            horizontal: sideGutter(MediaQuery.sizeOf(context).width, base: 0), vertical: 8)
            .copyWith(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'O backup guarda todas as suas rádios, com os logos. As gravações não entram (use Compartilhar na tela Gravações).',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Salvar backup no celular'),
            subtitle: const Text('Você escolhe a pasta (ex.: Downloads). Mesmo nome substitui o anterior.'),
            onTap: () => _saveOnPhone(context),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Compartilhar backup'),
            subtitle: const Text('Google Drive, WhatsApp, e-mail…'),
            onTap: () => _share(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurar backup'),
            subtitle: const Text('Escolha o arquivo webradio_backup.json'),
            onTap: () => _restore(context),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Importar links de rádios'),
            subtitle: const Text('Colar uma lista de links ou M3U'),
            onTap: () => _importText(context),
          ),
        ],
      ),
    );
  }
}
