import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
  final String state;
  final double? lat, lon;

  /// Distância até você (só na busca "Perto de mim").
  final double? km;

  const FoundStation({
    required this.uuid,
    required this.name,
    required this.url,
    required this.favicon,
    required this.tags,
    required this.country,
    required this.codec,
    required this.bitrate,
    this.state = '',
    this.lat,
    this.lon,
    this.km,
  });

  FoundStation withKm(double? km) => FoundStation(
      uuid: uuid,
      name: name,
      url: url,
      favicon: favicon,
      tags: tags,
      country: country,
      codec: codec,
      bitrate: bitrate,
      state: state,
      lat: lat,
      lon: lon,
      km: km);

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
      state: ((j['state'] as String?) ?? '').trim(),
      lat: (j['geo_lat'] as num?)?.toDouble(),
      lon: (j['geo_long'] as num?)?.toDouble(),
    );
  }

  String get details {
    final parts = <String>[
      if (km != null) km! < 1 ? 'aqui perto' : '${km!.round()} km',
      if (km == null && state.isNotEmpty) state,
      if (km == null && country.isNotEmpty) country,
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

  /// Rádios perto de você (1.8.7): as do seu país com posição no mapa até
  /// [radiusKm], mais próximas primeiro, e depois as do seu estado/região
  /// que não têm posição. País e estado vêm do OpenStreetMap (Nominatim).
  static Future<List<FoundStation>> nearby(double lat, double lon,
      {double radiusKm = 120}) async {
    String cc = '', state = '';
    try {
      final r = await http.get(
          Uri.https('nominatim.openstreetmap.org', '/reverse', {
            'format': 'json',
            'lat': '$lat',
            'lon': '$lon',
            'zoom': '8',
            'accept-language': 'pt',
          }),
          headers: {
            'User-Agent': 'WebRadio/1.0 (Android)'
          }).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final a = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['address']
            as Map?;
        cc = ((a?['country_code'] as String?) ?? '').toUpperCase();
        state = (a?['state'] as String?) ?? '';
      }
    } catch (_) {}
    final withGeo = await search(
        countryCode: cc, limit: 3000, extra: {'has_geo_info': 'true'});
    final out = <FoundStation>[];
    final seen = <String>{};
    for (final s in withGeo) {
      if (s.lat == null || s.lon == null) continue;
      final d = _km(lat, lon, s.lat!, s.lon!);
      if (d <= radiusKm && seen.add(s.url)) out.add(s.withKm(d));
    }
    out.sort((a, b) => a.km!.compareTo(b.km!));
    if (cc.isNotEmpty && state.isNotEmpty) {
      try {
        final byState = await search(
            countryCode: cc, limit: 200, extra: {'state': state});
        for (final s in byState) {
          if (seen.add(s.url)) out.add(s);
        }
      } catch (_) {}
    }
    return out;
  }

  static double _km(double la1, double lo1, double la2, double lo2) {
    const r = 6371.0;
    final dLa = (la2 - la1) * math.pi / 180, dLo = (lo2 - lo1) * math.pi / 180;
    final a = math.pow(math.sin(dLa / 2), 2) +
        math.cos(la1 * math.pi / 180) *
            math.cos(la2 * math.pi / 180) *
            math.pow(math.sin(dLo / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static Future<List<FoundStation>> search({
    String name = '',
    String tag = '',
    String countryCode = '',
    int limit = 60,
    Map<String, String> extra = const {},
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      if (name.trim().isNotEmpty) 'name': name.trim(),
      if (tag.trim().isNotEmpty) 'tag': tag.trim(),
      if (countryCode.isNotEmpty) 'countrycode': countryCode,
      ...extra,
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
