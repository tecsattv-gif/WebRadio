import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';
import 'firebase_api.dart';

/// Sincroniza a lista de rádios entre os celulares que usam o mesmo código.
/// Regra: vale a lista alterada por último.
class SyncService {
  static const _kCode = 'sync_code';
  static const _kLocalUpdated = 'sync_local_updated';
  static const _kSynced = 'sync_last_synced';

  final ValueNotifier<String?> code = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastSync = ValueNotifier(null);

  /// Chamado quando a lista de outro celular deve substituir a deste.
  void Function(List<Station> stations)? onRemoteList;

  /// Fornece a lista atual deste celular.
  List<Station> Function()? currentList;

  int _localUpdated = 0;
  Timer? _pushDebounce;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    code.value = prefs.getString(_kCode);
    _localUpdated = prefs.getInt(_kLocalUpdated) ?? 0;
    final synced = prefs.getInt(_kSynced);
    if (synced != null) lastSync.value = DateTime.fromMillisecondsSinceEpoch(synced);
  }

  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(16, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static String normalizeCode(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String formatCode(String c) {
    final b = StringBuffer();
    for (var i = 0; i < c.length; i++) {
      if (i > 0 && i % 4 == 0) b.write('-');
      b.write(c[i]);
    }
    return b.toString();
  }

  /// A lista deste celular mudou: marca a hora e envia (com pequeno atraso).
  Future<void> markLocalChange() async {
    _localUpdated = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLocalUpdated, _localUpdated);
    if (code.value == null) return;
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(seconds: 2), () => syncNow());
  }

  /// Cria um código novo e envia a lista deste celular.
  Future<String?> createCode() async {
    final c = generateCode();
    return _useCode(c, preferLocal: true);
  }

  /// Usa o código de outro celular: a lista dele substitui a deste.
  Future<String?> joinCode(String raw) async {
    final c = normalizeCode(raw);
    if (c.length < 12) return 'Código incompleto.';
    busy.value = true;
    try {
      final remote = await FirebaseApi.fetchList(c);
      if (remote == null) return 'Não existe lista com esse código.';
    } catch (e) {
      return e is FirebaseError ? e.message : 'Sem conexão com a internet.';
    } finally {
      busy.value = false;
    }
    return _useCode(c, preferLocal: false);
  }

  Future<String?> _useCode(String c, {required bool preferLocal}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCode, c);
    code.value = c;
    if (preferLocal) {
      _localUpdated = DateTime.now().millisecondsSinceEpoch;
    } else {
      _localUpdated = 0; // a lista do outro celular ganha
    }
    await prefs.setInt(_kLocalUpdated, _localUpdated);
    return syncNow();
  }

  Future<void> stopSync() async {
    _pushDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCode);
    await prefs.remove(_kSynced);
    code.value = null;
    lastSync.value = null;
    lastError.value = null;
  }

  /// Puxa ou envia, conforme qual lista é mais nova. Devolve erro ou null.
  Future<String?> syncNow() async {
    final c = code.value;
    if (c == null || busy.value) return null;
    busy.value = true;
    try {
      final remote = await FirebaseApi.fetchList(c);
      if (remote != null && remote.updatedAt > _localUpdated) {
        onRemoteList?.call(remote.stations);
        _localUpdated = remote.updatedAt;
      } else if (remote == null || _localUpdated > remote.updatedAt) {
        final list = currentList?.call() ?? const <Station>[];
        await FirebaseApi.saveList(c, list, _localUpdated);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLocalUpdated, _localUpdated);
      final now = DateTime.now();
      await prefs.setInt(_kSynced, now.millisecondsSinceEpoch);
      lastSync.value = now;
      lastError.value = null;
      return null;
    } catch (e) {
      final msg = e is FirebaseError ? e.message : 'Sem conexão com a internet.';
      lastError.value = msg;
      return msg;
    } finally {
      busy.value = false;
    }
  }
}
