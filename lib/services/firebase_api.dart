import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';

/// Acesso ao Firebase (projeto WebRadio001) pela API REST:
/// Firestore para as listas e Authentication só para o administrador.
class FirebaseApi {
  static const String apiKey = 'AIzaSyB-vNW98HcJa-5RBlqWWmTkKo-tc6AW2dA';
  static const String projectId = 'webradio001-c911b';
  static const String adminEmail = 'tecsattv@gmail.com';

  static const String _base =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
  static const Duration _timeout = Duration(seconds: 15);

  // ---------------------------------------------------------------- admin

  static const _kRefresh = 'admin_refresh_token';
  static final ValueNotifier<bool> isAdmin = ValueNotifier(false);
  static String? _idToken;
  static DateTime? _idTokenExpires;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isAdmin.value = prefs.getString(_kRefresh) != null;
  }

  /// Devolve mensagem de erro ou null se entrou.
  static Future<String?> adminLogin(String password) async {
    try {
      final r = await http
          .post(
            Uri.parse(
                'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': adminEmail,
              'password': password,
              'returnSecureToken': true,
            }),
          )
          .timeout(_timeout);
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200) {
        final msg = ((j['error'] as Map?)?['message'] ?? '').toString();
        if (msg.contains('PASSWORD') || msg.contains('INVALID') || msg.contains('CREDENTIAL')) {
          return 'Senha incorreta.';
        }
        if (msg.contains('TOO_MANY')) return 'Muitas tentativas. Espere alguns minutos.';
        return 'Não foi possível entrar ($msg).';
      }
      _idToken = j['idToken'] as String?;
      _idTokenExpires = DateTime.now().add(
          Duration(seconds: int.tryParse('${j['expiresIn']}') ?? 3600) -
              const Duration(minutes: 2));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRefresh, j['refreshToken'] as String);
      isAdmin.value = true;
      return null;
    } catch (_) {
      return 'Sem conexão com a internet.';
    }
  }

  static Future<void> adminLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRefresh);
    _idToken = null;
    isAdmin.value = false;
  }

  static Future<String> _adminToken() async {
    if (_idToken != null &&
        _idTokenExpires != null &&
        DateTime.now().isBefore(_idTokenExpires!)) {
      return _idToken!;
    }
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_kRefresh);
    if (refresh == null) throw const FirebaseError('Entre como administrador.');
    final r = await http.post(
      Uri.parse('https://securetoken.googleapis.com/v1/token?key=$apiKey'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(refresh)}',
    ).timeout(_timeout);
    if (r.statusCode != 200) {
      await adminLogout();
      throw const FirebaseError('Login expirou. Entre de novo como administrador.');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    _idToken = j['id_token'] as String;
    _idTokenExpires = DateTime.now().add(
        Duration(seconds: int.tryParse('${j['expires_in']}') ?? 3600) -
            const Duration(minutes: 2));
    final newRefresh = j['refresh_token'] as String?;
    if (newRefresh != null) await prefs.setString(_kRefresh, newRefresh);
    return _idToken!;
  }

  // ---------------------------------------------------------------- rádios públicas

  static Station _stationFromDoc(Map<String, dynamic> doc) {
    final f = (doc['fields'] as Map<String, dynamic>?) ?? const {};
    String? s(String k) => (f[k] as Map<String, dynamic>?)?['stringValue'] as String?;
    final id = (doc['name'] as String).split('/').last;
    return Station(
      id: id,
      name: s('name') ?? '',
      url: s('url') ?? '',
      genre: s('genre'),
      logoUrl: s('logoUrl'),
      logoData: s('logoData'),
    );
  }

  static Future<List<Station>> fetchPublic() async {
    final out = <Station>[];
    String? pageToken;
    do {
      final uri = Uri.parse('$_base/radios_publicas').replace(queryParameters: {
        'key': apiKey,
        'pageSize': '300',
        if (pageToken != null) 'pageToken': pageToken,
      });
      final r = await http.get(uri).timeout(_timeout);
      if (r.statusCode != 200) {
        throw FirebaseError('Erro ao buscar rádios sugeridas (${r.statusCode}).');
      }
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      for (final d in (j['documents'] as List<dynamic>? ?? const [])) {
        final st = _stationFromDoc(d as Map<String, dynamic>);
        if (st.url.isNotEmpty) out.add(st);
      }
      pageToken = j['nextPageToken'] as String?;
    } while (pageToken != null);
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  static Map<String, dynamic> _stationFields(Station s) => {
        'name': {'stringValue': s.name},
        'url': {'stringValue': s.url},
        if ((s.genre ?? '').isNotEmpty) 'genre': {'stringValue': s.genre},
        if ((s.logoUrl ?? '').isNotEmpty) 'logoUrl': {'stringValue': s.logoUrl},
        if ((s.logoData ?? '').isNotEmpty) 'logoData': {'stringValue': s.logoData},
        'criado': {'integerValue': '${DateTime.now().millisecondsSinceEpoch}'},
      };

  static Future<void> publish(Station s) async {
    final token = await _adminToken();
    final r = await http
        .post(
          Uri.parse('$_base/radios_publicas?key=$apiKey'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fields': _stationFields(s)}),
        )
        .timeout(_timeout);
    if (r.statusCode != 200) {
      throw FirebaseError('Não foi possível publicar (${r.statusCode}).');
    }
  }

  static Future<void> unpublish(String id) async {
    final token = await _adminToken();
    final r = await http.delete(
      Uri.parse('$_base/radios_publicas/$id?key=$apiKey'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);
    if (r.statusCode != 200) {
      throw FirebaseError('Não foi possível remover (${r.statusCode}).');
    }
  }

  // ---------------------------------------------------------------- lista sincronizada

  /// Devolve null se ainda não existe lista com esse código.
  static Future<SyncedList?> fetchList(String code) async {
    final r = await http
        .get(Uri.parse('$_base/listas/$code?key=$apiKey'))
        .timeout(_timeout);
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw FirebaseError('Erro ao sincronizar (${r.statusCode}).');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final f = (j['fields'] as Map<String, dynamic>?) ?? const {};
    final dados = (f['dados'] as Map<String, dynamic>?)?['stringValue'] as String? ?? '[]';
    final upd = int.tryParse(
            '${(f['atualizado'] as Map<String, dynamic>?)?['integerValue'] ?? '0'}') ??
        0;
    final list = (jsonDecode(dados) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Station.fromJson)
        .where((s) => s.url.isNotEmpty)
        .toList();
    return SyncedList(list, upd);
  }

  static Future<void> saveList(String code, List<Station> stations, int updatedAt) async {
    final r = await http
        .patch(
          Uri.parse('$_base/listas/$code?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fields': {
              'dados': {
                'stringValue': jsonEncode(stations.map((s) => s.toJson()).toList())
              },
              'atualizado': {'integerValue': '$updatedAt'},
            }
          }),
        )
        .timeout(_timeout);
    if (r.statusCode != 200) {
      throw FirebaseError('Erro ao enviar a lista (${r.statusCode}).');
    }
  }
}

class SyncedList {
  final List<Station> stations;
  final int updatedAt;
  const SyncedList(this.stations, this.updatedAt);
}

class FirebaseError implements Exception {
  final String message;
  const FirebaseError(this.message);
  @override
  String toString() => message;
}
