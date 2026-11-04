import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'stream_resolver.dart';

class RecordingInfo {
  final String path;
  final String stationName;
  final DateTime started;
  final int bytes;

  const RecordingInfo(this.path, this.stationName, this.started, this.bytes);

  Duration get elapsed => DateTime.now().difference(started);
}

/// Grava a transmissão da rádio direto em arquivo (sem recodificar).
class Recorder {
  final ValueNotifier<RecordingInfo?> state = ValueNotifier(null);

  http.Client? _client;
  StreamSubscription<List<int>>? _sub;
  IOSink? _sink;
  Timer? _ticker;
  int _bytes = 0;
  bool _stopping = false;

  bool get isRecording => state.value != null;

  static Future<Directory> folder() async {
    Directory? base;
    try {
      base = await getExternalStorageDirectory();
    } catch (_) {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Gravacoes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Devolve uma mensagem de erro, ou null se começou a gravar.
  Future<String?> start(String stationName, String url) async {
    if (isRecording) return null;
    if (url.toLowerCase().contains('.m3u8')) {
      return 'Esta rádio usa o formato HLS, que não dá para gravar.';
    }
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers['User-Agent'] = kUserAgent;
      final resp = await client.send(req).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 400) {
        client.close();
        return 'A rádio recusou a gravação (erro ${resp.statusCode}).';
      }
      final ct = (resp.headers['content-type'] ?? '').toLowerCase();
      if (ct.contains('mpegurl') || ct.contains('text/html')) {
        client.close();
        return 'O formato desta transmissão não dá para gravar.';
      }
      final ext = ct.contains('aac')
          ? 'aac'
          : ct.contains('ogg')
              ? 'ogg'
              : ct.contains('flac')
                  ? 'flac'
                  : 'mp3';

      final dir = await folder();
      final safe = stationName
          .replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ\- ]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final file = File(
          '${dir.path}/${safe.isEmpty ? 'radio' : safe}_${_stamp(DateTime.now())}.$ext');
      final sink = file.openWrite();
      final started = DateTime.now();

      _client = client;
      _sink = sink;
      _bytes = 0;
      state.value = RecordingInfo(file.path, stationName, started, 0);

      _sub = resp.stream.listen(
        (chunk) {
          sink.add(chunk);
          _bytes += chunk.length;
        },
        onError: (Object _) => stop(),
        onDone: () => stop(),
        cancelOnError: true,
      );
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final s = state.value;
        if (s != null) {
          state.value = RecordingInfo(s.path, s.stationName, s.started, _bytes);
        }
      });
      return null;
    } catch (_) {
      client.close();
      return 'Não foi possível começar a gravar esta rádio.';
    }
  }

  Future<void> stop() async {
    if (_stopping || state.value == null) return;
    _stopping = true;
    try {
      _ticker?.cancel();
      _ticker = null;
      await _sub?.cancel();
      _sub = null;
      try {
        await _sink?.flush();
        await _sink?.close();
      } catch (_) {}
      _sink = null;
      _client?.close();
      _client = null;
      state.value = null;
    } finally {
      _stopping = false;
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}_${_two(d.hour)}${_two(d.minute)}${_two(d.second)}';
}
