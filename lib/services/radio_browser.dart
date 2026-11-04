import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Uma rádio encontrada no diretório Radio Browser.
class FoundStation {
  final String uuid;
  final String name;
  final String url;
  final String favicon;
  final List<String> tags;
  final String country;
  final String codec;
  final int bitrate;

  const FoundStation({
    required this.uuid,
    required this.name,
    required this.url,
    required this.favicon,
    required this.tags,
    required this.country,
    required this.codec,
    required this.bitrate,
  });

  factory FoundStation.fromJson(Map<String, dynamic> j) {
    final resolved = (j['url_resolved'] as String?)?.trim() ?? '';
    return FoundStation(
      uuid: (j['stationuuid'] as String?) ?? '',
      name: ((j['name'] as String?) ?? '').trim(),
      url: resolved.isNotEmpty ? resolved : ((j['url'] as String?) ?? '').trim(),
      favicon: ((j['favicon'] as String?) ?? '').trim(),
      tags: ((j['tags'] as String?) ?? '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      country: ((j['country'] as String?) ?? '').trim(),
      codec: ((j['codec'] as String?) ?? '').trim(),
      bitrate: (j['bitrate'] as num?)?.toInt() ?? 0,
    );
  }

  String get details {
    final parts = <String>[
      if (country.isNotEmpty) country,
      if (tags.isNotEmpty) tags.take(3).join(', '),
      if (codec.isNotEmpty) bitrate > 0 ? '$codec $bitrate kbps' : codec,
    ];
    return parts.join(' · ');
  }
}

/// Busca no Radio Browser (diretório gratuito e aberto de rádios do mundo).
class RadioBrowser {
  static const _servers = [
    'de1.api.radio-browser.info',
    'fi1.api.radio-browser.info',
    'de2.api.radio-browser.info',
    'nl1.api.radio-browser.info',
  ];
  static int _server = 0;

  static Future<List<FoundStation>> search({
    String name = '',
    String tag = '',
    String countryCode = '',
    int limit = 60,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      if (name.trim().isNotEmpty) 'name': name.trim(),
      if (tag.trim().isNotEmpty) 'tag': tag.trim(),
      if (countryCode.isNotEmpty) 'countrycode': countryCode,
    };
    Object? lastError;
    for (var attempt = 0; attempt < _servers.length; attempt++) {
      final host = _servers[(_server + attempt) % _servers.length];
      try {
        final uri = Uri.https(host, '/json/stations/search', params);
        final r = await http.get(uri, headers: {
          'User-Agent': 'WebRadio/1.0 (Android)',
        }).timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) {
          lastError = 'http ${r.statusCode}';
          continue;
        }
        _server = (_server + attempt) % _servers.length;
        final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
        final seen = <String>{};
        return list
            .whereType<Map<String, dynamic>>()
            .map(FoundStation.fromJson)
            .where((s) => s.url.startsWith('http') && s.name.isNotEmpty)
            .where((s) => seen.add(s.url))
            .toList();
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('Radio Browser indisponível ($lastError)');
  }

  /// Conta um "clique" na rádio (ajuda o ranking do diretório). Ignora erros.
  static void countClick(String uuid) {
    if (uuid.isEmpty) return;
    final host = _servers[_server];
    http
        .get(Uri.https(host, '/json/url/$uuid'),
            headers: {'User-Agent': 'WebRadio/1.0 (Android)'})
        .timeout(const Duration(seconds: 8))
        .then((_) {}, onError: (_) {});
  }
}
