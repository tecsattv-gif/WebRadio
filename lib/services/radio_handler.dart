import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/station.dart';
import 'recorder.dart';
import 'station_store.dart';
import 'stream_resolver.dart';
import 'sync_service.dart';

enum RadioStatus { idle, connecting, playing, paused, reconnecting, error }

/// Coração do app: toca a rádio, controla notificação, tela de bloqueio,
/// fone de ouvido e Android Auto (tudo via audio_service).
class RadioHandler extends BaseAudioHandler {
  static const String _folderId = 'minhas_radios';

  final AudioPlayer _player = AudioPlayer();
  final Recorder recorder = Recorder();
  final SyncService sync = SyncService();

  final ValueNotifier<List<Station>> stations = ValueNotifier(const []);
  final ValueNotifier<Station?> current = ValueNotifier(null);
  final ValueNotifier<String?> songTitle = ValueNotifier(null);
  final ValueNotifier<String?> message = ValueNotifier(null);
  final ValueNotifier<RadioStatus> status = ValueNotifier(RadioStatus.idle);
  final ValueNotifier<Duration?> sleepRemaining = ValueNotifier(null);

  bool _wantPlaying = false;
  bool _stopped = true;
  bool _loading = false;
  bool _hadPlayback = false;
  int _retries = 0;
  int _loadToken = 0;
  String? _resolvedUrl;
  Timer? _retryTimer;
  Timer? _sleepTimer;
  String? _artDir;

  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

    try {
      _artDir = (await getTemporaryDirectory()).path;
    } catch (_) {}

    stations.value = await StationStore.load();
    _publishQueue();
    final lastId = await StationStore.loadLastStationId();
    if (lastId != null) {
      for (final s in stations.value) {
        if (s.id == lastId) {
          _setCurrent(s);
          break;
        }
      }
    }

    await sync.init();
    sync.currentList = () => stations.value;
    sync.onRemoteList = applySyncedList;
    unawaited(sync.syncNow());

    _player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object e, StackTrace st) => _onStreamError(e),
    );
    _player.playingStream.listen((_) => _broadcast());
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && _wantPlaying) {
        // Transmissão ao vivo "terminou" = conexão caiu.
        _scheduleRetry();
      }
      _broadcast();
    });
    _player.icyMetadataStream.listen((icy) {
      final t = icy?.info?.title?.trim();
      _setSongTitle(t == null || t.isEmpty ? null : t);
    });
    _broadcast();
  }

  // ---------------------------------------------------------------- estado

  int? get _currentIndex {
    final c = current.value;
    if (c == null) return null;
    final i = stations.value.indexWhere((s) => s.id == c.id);
    return i < 0 ? null : i;
  }

  bool get isActive =>
      status.value == RadioStatus.playing ||
      status.value == RadioStatus.connecting ||
      status.value == RadioStatus.reconnecting;

  MediaItem _itemFor(Station s, {String? song}) {
    final logo = s.logoUrl?.trim() ?? '';
    final genre = s.genre?.trim() ?? '';
    return MediaItem(
      id: s.id,
      title: song ?? s.name,
      artist: song != null ? s.name : (genre.isNotEmpty ? genre : 'Rádio ao vivo'),
      album: s.name,
      artUri: _artFileFor(s) ?? (logo.isEmpty ? null : Uri.tryParse(logo)),
      playable: true,
    );
  }

  /// Logo convertido vira arquivo, para aparecer na notificação e no carro.
  Uri? _artFileFor(Station s) {
    final data = s.logoData;
    final dir = _artDir;
    if (data == null || data.isEmpty || dir == null) return null;
    try {
      final f = File('$dir/logo_${s.id}_${data.length}.png');
      if (!f.existsSync()) f.writeAsBytesSync(base64Decode(data));
      return Uri.file(f.path);
    } catch (_) {
      return null;
    }
  }

  void _setCurrent(Station s) {
    current.value = s;
    songTitle.value = null;
    _resolvedUrl = null;
    mediaItem.add(_itemFor(s));
  }

  void _setSongTitle(String? t) {
    final s = current.value;
    if (s == null) return;
    // Algumas rádios mandam o próprio nome como "música": ignora.
    final song = (t != null && t.toLowerCase() == s.name.toLowerCase()) ? null : t;
    if (song == songTitle.value) return;
    songTitle.value = song;
    mediaItem.add(_itemFor(s, song: song));
  }

  RadioStatus _computeStatus() {
    if (_stopped || current.value == null) {
      return message.value != null ? RadioStatus.error : RadioStatus.idle;
    }
    if (_retryTimer?.isActive ?? false) return RadioStatus.reconnecting;
    final ps = _player.processingState;
    if (_wantPlaying &&
        (_loading ||
            ps == ProcessingState.loading ||
            ps == ProcessingState.buffering)) {
      return RadioStatus.connecting;
    }
    if (_player.playing && ps == ProcessingState.ready) return RadioStatus.playing;
    if (!_wantPlaying && message.value != null) return RadioStatus.error;
    return RadioStatus.paused;
  }

  void _broadcast() {
    final st = _computeStatus();
    if (st == RadioStatus.playing) {
      _hadPlayback = true;
      if (_retries != 0 || message.value != null) {
        _retries = 0;
        message.value = null;
      }
    }
    status.value = st;

    final showPause = st == RadioStatus.playing ||
        st == RadioStatus.connecting ||
        st == RadioStatus.reconnecting;
    final AudioProcessingState aps = switch (st) {
      RadioStatus.idle || RadioStatus.error => _stopped
          ? AudioProcessingState.idle
          : AudioProcessingState.ready,
      RadioStatus.connecting ||
      RadioStatus.reconnecting =>
        AudioProcessingState.buffering,
      _ => AudioProcessingState.ready,
    };

    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        showPause ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.playPause,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.playFromMediaId,
        MediaAction.playFromSearch,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: aps,
      playing: showPause,
      queueIndex: _currentIndex,
      updatePosition: Duration.zero,
    ));
  }

  // ------------------------------------------------------------ reprodução

  Future<void> playStation(Station s) async {
    if (current.value?.id != s.id) {
      if (recorder.isRecording) await recorder.stop();
      _setCurrent(s);
      unawaited(StationStore.saveLastStationId(s.id));
    }
    _wantPlaying = true;
    _stopped = false;
    _retries = 0;
    _hadPlayback = false;
    message.value = null;
    await _startStream();
  }

  Future<void> _startStream() async {
    final s = current.value;
    if (s == null) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    final token = ++_loadToken;
    _loading = true;
    _broadcast();
    try {
      final url = await resolveStreamUrl(s.url);
      if (token != _loadToken) return;
      _resolvedUrl = url;
      await _player.setUrl(url);
      if (token != _loadToken) return;
      _loading = false;
      if (_wantPlaying) unawaited(_player.play());
      _broadcast();
    } on PlayerInterruptedException {
      // Outra rádio começou a carregar no meio: tudo certo.
    } catch (e) {
      if (token != _loadToken) return;
      _loading = false;
      _onStreamError(e);
    }
  }

  void _onStreamError(Object e) {
    if (!_wantPlaying) return;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return;
    final s = current.value;
    if (s == null) return;
    // Link que nunca tocou: desiste rápido. Rádio que já estava tocando
    // (ex.: caiu o sinal na estrada): insiste bem mais.
    final maxRetries = _hadPlayback ? 15 : 2;
    if (_retries >= maxRetries) {
      _wantPlaying = false;
      _loading = false;
      message.value = _hadPlayback
          ? 'A conexão com "${s.name}" caiu. Toque play para tentar de novo.'
          : 'Não foi possível tocar "${s.name}". Confira o link ou a internet.';
      unawaited(_player.stop());
      _broadcast();
      return;
    }
    _retries++;
    message.value = 'Reconectando… ($_retries/$maxRetries)';
    final secs = _retries * 2 > 10 ? 10 : _retries * 2;
    _retryTimer = Timer(Duration(seconds: secs), () {
      _retryTimer = null;
      if (_wantPlaying) {
        _startStream();
      } else {
        _broadcast();
      }
    });
    _broadcast();
  }

  Future<void> togglePlay() async {
    if (isActive) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> play() async {
    final s = current.value ??
        (stations.value.isNotEmpty ? stations.value.first : null);
    if (s == null) return;
    if (current.value?.id == s.id && status.value == RadioStatus.playing) return;
    // Rádio ao vivo: sempre reconecta, para não tocar áudio "velho".
    await playStation(s);
  }

  @override
  Future<void> pause() async {
    _wantPlaying = false;
    _loading = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    _loadToken++;
    if (message.value != null && message.value!.startsWith('Reconectando')) {
      message.value = null;
    }
    await _player.stop();
    _broadcast();
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    await pause();
    cancelSleepTimer();
    await recorder.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() => _skip(1);

  @override
  Future<void> skipToPrevious() => _skip(-1);

  Future<void> _skip(int delta) async {
    final list = stations.value;
    if (list.isEmpty) return;
    final i = _currentIndex ?? -1;
    final next = (i + delta) % list.length;
    await playStation(list[next < 0 ? next + list.length : next]);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final list = stations.value;
    if (index < 0 || index >= list.length) return;
    await playStation(list[index]);
  }

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    for (final s in stations.value) {
      if (s.id == mediaId) {
        await playStation(s);
        return;
      }
    }
  }

  /// "Ok Google, tocar <rádio> no WebRádio" (Android Auto / Assistente).
  @override
  Future<void> playFromSearch(String query,
      [Map<String, dynamic>? extras]) async {
    final q = _normalize(query);
    if (q.isEmpty) {
      await play();
      return;
    }
    Station? best;
    for (final s in stations.value) {
      final n = _normalize(s.name);
      if (n == q) {
        best = s;
        break;
      }
      if (best == null && (n.contains(q) || q.contains(n))) best = s;
    }
    if (best != null) {
      await playStation(best);
    } else {
      await play();
    }
  }

  static String _normalize(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final lower = s.toLowerCase().trim();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  @override
  Future<void> onTaskRemoved() async {
    if (!_wantPlaying) await stop();
  }

  // ------------------------------------------------------------ Android Auto

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    if (parentMediaId == AudioService.browsableRootId) {
      return [
        MediaItem(id: _folderId, title: 'Minhas rádios', playable: false),
      ];
    }
    if (parentMediaId == AudioService.recentRootId) {
      final c = current.value;
      return c == null ? <MediaItem>[] : [_itemFor(c)];
    }
    return stations.value.map((s) => _itemFor(s)).toList();
  }

  // ------------------------------------------------------------ timer

  void startSleepTimer(Duration d) {
    _sleepTimer?.cancel();
    unawaited(_player.setVolume(1));
    final end = DateTime.now().add(d);
    sleepRemaining.value = d;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) {
        t.cancel();
        _sleepTimer = null;
        sleepRemaining.value = null;
        unawaited(stop());
        return;
      }
      sleepRemaining.value = left;
      // Abaixa o volume aos poucos nos últimos 20 segundos.
      if (left.inSeconds < 20) {
        unawaited(_player.setVolume(left.inMilliseconds / 20000));
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepRemaining.value = null;
    unawaited(_player.setVolume(1));
  }

  // ------------------------------------------------------------ gravação

  /// Liga/desliga a gravação. Devolve mensagem de erro ou null.
  Future<String?> toggleRecording() async {
    if (recorder.isRecording) {
      await recorder.stop();
      return null;
    }
    final s = current.value;
    if (s == null) return 'Escolha uma rádio primeiro.';
    final url = _resolvedUrl ?? await resolveStreamUrl(s.url);
    return recorder.start(s.name, url);
  }

  // ------------------------------------------------------------ lista

  Future<void> addStation(Station s) async {
    stations.value = [...stations.value, s];
    await _persist();
  }

  Future<void> updateStation(Station s) async {
    stations.value = [
      for (final e in stations.value) e.id == s.id ? s : e,
    ];
    if (current.value?.id == s.id) {
      final urlChanged = current.value!.url != s.url;
      current.value = s;
      mediaItem.add(_itemFor(s, song: songTitle.value));
      if (urlChanged) {
        _resolvedUrl = null;
        if (isActive) unawaited(playStation(s));
      }
    }
    await _persist();
  }

  Future<void> removeStation(String id) async {
    if (current.value?.id == id) {
      await stop();
      current.value = null;
      songTitle.value = null;
      mediaItem.add(null);
    }
    stations.value = stations.value.where((s) => s.id != id).toList();
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...stations.value];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    stations.value = list;
    await _persist();
    _broadcast();
  }

  /// Junta rádios importadas, ignorando links repetidos. Devolve quantas entraram.
  Future<int> importStations(List<Station> incoming) async {
    final urls = stations.value.map((s) => s.url.trim()).toSet();
    final add = <Station>[];
    for (final s in incoming) {
      final u = s.url.trim();
      if (u.isEmpty || urls.contains(u)) continue;
      urls.add(u);
      add.add(s);
    }
    if (add.isEmpty) return 0;
    stations.value = [...stations.value, ...add];
    await _persist();
    return add.length;
  }

  Future<void> _persist() async {
    await StationStore.save(stations.value);
    _publishQueue();
    unawaited(sync.markLocalChange());
  }

  /// Lista que veio de outro celular (sincronização): substitui a deste.
  void applySyncedList(List<Station> list) {
    stations.value = List.unmodifiable(list);
    unawaited(StationStore.save(list));
    _publishQueue();
    final c = current.value;
    if (c != null) {
      for (final s in list) {
        if (s.id == c.id) {
          current.value = s;
          break;
        }
      }
    }
    _broadcast();
  }

  void _publishQueue() {
    queue.add(stations.value.map((s) => _itemFor(s)).toList());
  }
}
