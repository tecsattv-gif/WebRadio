import 'package:flutter/material.dart';

import '../models/station.dart';

const String kNoGenre = '\u0000sem';

String genreKey(Station s) {
  final g = (s.genre ?? '').trim().toLowerCase();
  return g.isEmpty ? kNoGenre : g;
}

/// Gêneros da lista (sem repetir maiúsculas/minúsculas), com quantidade.
/// Devolve pares (chave, nome para mostrar, quantidade), em ordem alfabética.
List<(String, String, int)> genresOf(List<Station> list) {
  final names = <String, String>{};
  final counts = <String, int>{};
  for (final s in list) {
    final k = genreKey(s);
    names.putIfAbsent(k, () => k == kNoGenre ? 'Sem gênero' : s.genre!.trim());
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final keys = names.keys.toList()
    ..sort((a, b) {
      if (a == kNoGenre) return 1;
      if (b == kNoGenre) return -1;
      return a.compareTo(b);
    });
  return [for (final k in keys) (k, names[k]!, counts[k]!)];
}

/// Fileira de botões: Todas + um por gênero.
class GenreChips extends StatelessWidget {
  final List<Station> stations;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const GenreChips({
    super.key,
    required this.stations,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final genres = genresOf(stations);
    // Só vale a pena mostrar se houver pelo menos um gênero de verdade.
    if (genres.isEmpty || (genres.length == 1 && genres.first.$1 == kNoGenre)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, bool sel, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: sel,
            onSelected: (_) => onTap(),
            showCheckmark: false,
            selectedColor: scheme.primary,
            labelStyle: TextStyle(
              color: sel ? Colors.black : Colors.white,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            side: BorderSide(color: Colors.white.withValues(alpha: sel ? 0 : 0.10)),
            shape: const StadiumBorder(),
          ),
        );
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          chip('Todas · ${stations.length}', selected == null, () => onSelected(null)),
          for (final g in genres)
            chip('${g.$2} · ${g.$3}', selected == g.$1,
                () => onSelected(selected == g.$1 ? null : g.$1)),
        ],
      ),
    );
  }
}
