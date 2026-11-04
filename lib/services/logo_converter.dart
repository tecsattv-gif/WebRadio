import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

/// Converte qualquer imagem (link ou galeria) num logo pequeno em PNG,
/// guardado como texto base64 dentro da própria rádio.
class LogoConverter {
  static const int size = 128;

  /// Baixa a imagem do link e converte. Devolve base64 ou lança erro com mensagem.
  static Future<String> fromUrl(String url) async {
    final http.Response r;
    try {
      r = await http.get(Uri.parse(url.trim()), headers: {
        'User-Agent': 'Mozilla/5.0 (Android) WebRadio',
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const LogoError('Não consegui baixar a imagem desse link.');
    }
    if (r.statusCode >= 400) {
      throw LogoError('O link da imagem respondeu com erro ${r.statusCode}.');
    }
    final ct = (r.headers['content-type'] ?? '').toLowerCase();
    if (ct.contains('svg')) {
      throw const LogoError('Imagens SVG não são aceitas. Use um link .png ou .jpg.');
    }
    if (ct.contains('text/html')) {
      throw const LogoError(
          'Esse link é de uma página, não de uma imagem. Segure o dedo no logo e use "Copiar endereço da imagem".');
    }
    return fromBytes(r.bodyBytes);
  }

  /// Converte bytes de imagem (PNG, JPG, WEBP, GIF...) para PNG de no máximo 128 px.
  static Future<String> fromBytes(Uint8List bytes) async {
    try {
      final probe = await ui.instantiateImageCodec(bytes);
      final first = (await probe.getNextFrame()).image;
      final w = first.width;
      final h = first.height;
      first.dispose();
      probe.dispose();

      ui.Image img;
      if (w <= size && h <= size) {
        final codec = await ui.instantiateImageCodec(bytes);
        img = (await codec.getNextFrame()).image;
      } else {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: w >= h ? size : null,
          targetHeight: h > w ? size : null,
        );
        img = (await codec.getNextFrame()).image;
      }
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (data == null) throw const LogoError('Não consegui converter a imagem.');
      return base64Encode(data.buffer.asUint8List());
    } on LogoError {
      rethrow;
    } catch (_) {
      throw const LogoError('Esse arquivo não é uma imagem que o app consiga ler.');
    }
  }
}

class LogoError implements Exception {
  final String message;
  const LogoError(this.message);
  @override
  String toString() => message;
}
