import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';

/// Guarda a lista de rádios no próprio telefone.
class StationStore {
  static const _kStations = 'stations_v1';
  static const _kLast = 'last_station_id';

  static Future<List<Station>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStations);
    // 1.8.6: na primeira vez (lista nunca salva) o app já vem com as rádios
    // da lista padrão (assets/default_stations.json, um backup do app).
    // Se o usuário apagar todas depois, a lista fica vazia (não volta).
    if (raw == null) {
      final defaults = await _loadDefaults();
      if (defaults.isNotEmpty) await save(defaults);
      return defaults;
    }
    if (raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Station.fromJson)
          .where((s) => s.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Station>> _loadDefaults() async {
    try {
      final text = await rootBundle.loadString('assets/default_stations.json');
      return parseImport(text);
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Station> stations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kStations, jsonEncode(stations.map((s) => s.toJson()).toList()));
  }

  static Future<String?> loadLastStationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLast);
  }

  static Future<void> saveLastStationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLast, id);
  }

  static String exportJson(List<Station> stations) =>
      const JsonEncoder.withIndent('  ').convert({
        'app': 'WebRadio',
        'stations': stations.map((s) => s.toJson()).toList(),
      });

  /// Aceita a lista exportada (JSON) ou texto com uma rádio por linha:
  /// "Nome | http://link" ou só "http://link".
  static List<Station> parseImport(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        final List<dynamic> list = decoded is Map<String, dynamic>
            ? (decoded['stations'] as List<dynamic>? ?? const [])
            : decoded as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map((j) => Station.fromJson(j).copyWith(id: Station.newId()))
            .where((s) => s.url.isNotEmpty)
            .map((s) => s.name.isEmpty ? s.copyWith(name: _nameFromUrl(s.url)) : s)
            .toList();
      } catch (_) {
        // cai para o modo linha a linha
      }
    }
    final result = <Station>[];
    String? pendingName;
    for (final raw in const LineSplitter().convert(trimmed)) {
      final line = raw.trim();
      if (line.isEmpty || line == '#EXTM3U') continue;
      if (line.startsWith('#EXTINF')) {
        final i = line.indexOf(',');
        pendingName = i >= 0 ? line.substring(i + 1).trim() : null;
        continue;
      }
      String name;
      String url;
      if (line.contains('|')) {
        final parts = line.split('|');
        name = parts.first.trim();
        url = parts.sublist(1).join('|').trim();
      } else {
        url = line;
        name = pendingName ?? _nameFromUrl(line);
      }
      pendingName = null;
      if (!url.startsWith('http://') && !url.startsWith('https://')) continue;
      result.add(Station(
          id: Station.newId(),
          name: name.isEmpty ? _nameFromUrl(url) : name,
          url: url));
    }
    return result;
  }

  static String _nameFromUrl(String url) =>
      Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? 'Rádio';
}
