import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const String kUserAgent = 'WebRadio/1.0 (Android)';

bool _isPlaylistUrl(String url) {
  final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
  return path.endsWith('.pls') || path.endsWith('.m3u') || path.endsWith('.asx');
}

/// Se o link for uma playlist (.pls / .m3u / .asx), devolve o primeiro
/// endereço de áudio que estiver dentro dela. Senão devolve o próprio link.
Future<String> resolveStreamUrl(String url) async {
  final u = url.trim();
  if (!_isPlaylistUrl(u)) return u;
  try {
    final r = await http
        .get(Uri.parse(u), headers: {'User-Agent': kUserAgent})
        .timeout(const Duration(seconds: 10));
    final found = _firstUrlIn(latin1.decode(r.bodyBytes, allowInvalid: true));
    return found ?? u;
  } catch (_) {
    return u;
  }
}

String? _firstUrlIn(String body) {
  final pls = RegExp(r'^\s*File\d+\s*=\s*(\S+)', caseSensitive: false, multiLine: true);
  final m1 = pls.firstMatch(body);
  if (m1 != null) return m1.group(1);
  final asx = RegExp(r'''href\s*=\s*["']([^"']+)["']''', caseSensitive: false);
  final m2 = asx.firstMatch(body);
  if (m2 != null) return m2.group(1);
  for (final raw in const LineSplitter().convert(body)) {
    final line = raw.trim();
    if (line.startsWith('http://') || line.startsWith('https://')) return line;
  }
  return null;
}

/// Testa o link da rádio e devolve um texto curto para mostrar ao usuário.
Future<String> checkStream(String url) async {
  final client = http.Client();
  try {
    final resolved = await resolveStreamUrl(url);
    final req = http.Request('GET', Uri.parse(resolved))
      ..headers['User-Agent'] = kUserAgent;
    final resp = await client.send(req).timeout(const Duration(seconds: 10));
    final ct = resp.headers['content-type'] ?? 'desconhecido';
    if (resp.statusCode >= 400) {
      return 'A rádio respondeu com erro ${resp.statusCode}.';
    }
    final lower = ct.toLowerCase();
    if (lower.startsWith('audio/') ||
        lower.contains('mpegurl') ||
        lower.contains('ogg') ||
        lower.contains('octet-stream')) {
      return 'Link OK ($ct).';
    }
    if (lower.contains('text/html')) {
      return 'Esse link é de uma página, não do áudio. Procure o link do "streaming" ou "ouvir no player externo".';
    }
    return 'Respondeu, mas o tipo é "$ct". Tente tocar para conferir.';
  } on TimeoutException {
    return 'A rádio não respondeu (tempo esgotado).';
  } catch (_) {
    return 'Não consegui acessar esse link.';
  } finally {
    client.close();
  }
}
