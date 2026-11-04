import 'dart:math';

/// Uma rádio da lista do usuário.
class Station {
  final String id;
  final String name;
  final String url;
  final String? genre;
  final String? logoUrl;

  /// Logo convertido (PNG pequeno em base64). Tem prioridade sobre logoUrl.
  final String? logoData;

  const Station({
    required this.id,
    required this.name,
    required this.url,
    this.genre,
    this.logoUrl,
    this.logoData,
  });

  static final Random _rnd = Random();

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${_rnd.nextInt(1 << 30).toRadixString(36)}';

  Station copyWith({
    String? id,
    String? name,
    String? url,
    String? genre,
    String? logoUrl,
    String? logoData,
  }) =>
      Station(
        id: id ?? this.id,
        name: name ?? this.name,
        url: url ?? this.url,
        genre: genre ?? this.genre,
        logoUrl: logoUrl ?? this.logoUrl,
        logoData: logoData ?? this.logoData,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        if (genre != null && genre!.isNotEmpty) 'genre': genre,
        if (logoUrl != null && logoUrl!.isNotEmpty) 'logoUrl': logoUrl,
        if (logoData != null && logoData!.isNotEmpty) 'logoData': logoData,
      };

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        id: (j['id'] as String?) ?? newId(),
        name: (j['name'] as String?)?.trim() ?? '',
        url: (j['url'] as String?)?.trim() ?? '',
        genre: (j['genre'] as String?)?.trim(),
        logoUrl: (j['logoUrl'] as String?)?.trim(),
        logoData: j['logoData'] as String?,
      );
}
