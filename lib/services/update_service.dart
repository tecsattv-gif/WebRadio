import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Procura versão nova nas Releases do GitHub e instala com autorização do usuário.
class UpdateService {
  static const String _latestUrl =
      'https://api.github.com/repos/tecsattv-gif/webradio/releases/latest';

  static bool _checkedThisSession = false;

  /// Compara "1.10.0" com "1.9.2". Devolve >0 se a for maior.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .replaceAll(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final pa = parts(a);
    final pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  static Future<_Release?> _fetchLatest() async {
    final r = await http.get(Uri.parse(_latestUrl), headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'WebRadio-App',
    }).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final tag = (j['tag_name'] as String?) ?? '';
    String? apk;
    for (final a in (j['assets'] as List<dynamic>? ?? const [])) {
      final m = a as Map<String, dynamic>;
      final name = (m['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apk = m['browser_download_url'] as String?;
        break;
      }
    }
    if (tag.isEmpty || apk == null) return null;
    return _Release(tag.replaceAll(RegExp(r'^[vV]'), ''), apk, (j['body'] as String?) ?? '');
  }

  /// Ao abrir o app: só avisa se houver versão nova (uma vez por sessão).
  static Future<void> checkOnStart(BuildContext context) async {
    if (_checkedThisSession) return;
    _checkedThisSession = true;
    await _check(context, silent: true);
  }

  /// Pelo menu: também avisa quando já está na última versão.
  static Future<void> checkManually(BuildContext context) => _check(context, silent: false);

  static Future<void> _check(BuildContext context, {required bool silent}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final info = await PackageInfo.fromPlatform();
      final latest = await _fetchLatest();
      if (latest == null || compareVersions(latest.version, info.version) <= 0) {
        if (!silent) {
          messenger.showSnackBar(SnackBar(
              content: Text('Você já está na versão mais nova (${info.version}).')));
        }
        return;
      }
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nova versão disponível'),
          content: Text(
            'Versão ${latest.version} (você tem a ${info.version}).\n\n'
            'Quer baixar e instalar agora?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Depois')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Atualizar'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await _downloadAndInstall(context, latest);
    } catch (_) {
      if (!silent) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Não consegui verificar atualizações. Confira a internet.')));
      }
    }
  }

  static Future<void> _downloadAndInstall(BuildContext context, _Release rel) async {
    final progress = ValueNotifier<double?>(null);
    var cancelled = false;
    final client = http.Client();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Baixando versão ${rel.version}'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (_, p, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: p),
              const SizedBox(height: 10),
              Text(p == null ? 'Conectando…' : '${(p * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              client.close();
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/WebRadio-${rel.version}.apk');
      final resp = await client.send(http.Request('GET', Uri.parse(rel.apkUrl)));
      if (resp.statusCode != 200) throw Exception('http ${resp.statusCode}');
      final total = resp.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) progress.value = received / total;
      }
      await sink.close();
      if (cancelled) return;
      nav.pop();
      final res = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (res.type != ResultType.done) {
        messenger.showSnackBar(SnackBar(
          content: Text(
              'Não consegui abrir o instalador. Permita "Instalar apps desconhecidos" para o WebRádio nas configurações do Android. (${res.message})'),
          duration: const Duration(seconds: 8),
        ));
      }
    } catch (_) {
      if (cancelled) return;
      nav.pop();
      messenger.showSnackBar(
          const SnackBar(content: Text('O download da atualização falhou. Tente de novo.')));
    } finally {
      client.close();
    }
  }
}

class _Release {
  final String version;
  final String apkUrl;
  final String notes;
  const _Release(this.version, this.apkUrl, this.notes);
}
