import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Тренажер «Покіт: розкладка здобичі» — ті самі колекції й поля, що на сайті
// (site/js/views/trainer-pokit.js). Порядок покоту задає викладач через
// pokitRank; код лише сортує за ним. (Не плутати з категорією сигналів
// «Сигнали покоту» — інше значення слова.)

double _num(dynamic v, [double d = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? d;

/// Іконки, які пропонує форма виду (ті самі назви, що на сайті). Довільну
/// назву Material-іконки Flutter показати не може (іконки «витрушуються»
/// при збірці), тож для неї — лапа.
const pokitIcons = <String, (IconData, String)>{
  'pets': (Icons.pets, 'Звір (лапа)'),
  'cruelty_free': (Icons.cruelty_free, 'Заєць'),
  'flutter_dash': (Icons.flutter_dash, 'Птах'),
  'emoji_nature': (Icons.emoji_nature, 'Комаха/дрібна дичина'),
  'forest': (Icons.forest, 'Ліс'),
  'set_meal': (Icons.set_meal, 'Риба'),
  'egg': (Icons.egg, 'Яйце'),
  'spa': (Icons.spa, 'Листок'),
};
IconData pokitIconData(String? name) => pokitIcons[name]?.$1 ?? Icons.pets;

class PokitSpecies {
  final String id;
  final String name;
  final String icon;
  final String? imageUrl;
  final double pokitRank;
  final bool hidden;
  final int sortOrder;
  final String? signalId;

  const PokitSpecies({
    required this.id,
    required this.name,
    this.icon = 'pets',
    this.imageUrl,
    this.pokitRank = 0,
    this.hidden = false,
    this.sortOrder = 0,
    this.signalId,
  });

  factory PokitSpecies.fromJson(String docId, Map<String, dynamic> j) => PokitSpecies(
        id: (j['id']?.toString().isNotEmpty ?? false) ? j['id'].toString() : docId,
        name: j['name']?.toString() ?? '',
        icon: j['icon']?.toString() ?? 'pets',
        imageUrl: (j['imageUrl']?.toString().isNotEmpty ?? false) ? j['imageUrl'].toString() : null,
        pokitRank: _num(j['pokitRank']),
        hidden: j['hidden'] == true,
        sortOrder: _num(j['sortOrder']).round(),
        signalId: (j['signalId']?.toString().isNotEmpty ?? false) ? j['signalId'].toString() : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.trim(),
        'icon': icon,
        'imageUrl': imageUrl,
        'pokitRank': pokitRank,
        'hidden': hidden,
        'signalId': signalId,
        'sortOrder': sortOrder,
      };
}

class PokitConfig {
  final int minSpecies, maxSpecies, minCountPerSpecies, maxCountPerSpecies;
  final bool groupingRequired;

  const PokitConfig({
    this.minSpecies = 2,
    this.maxSpecies = 4,
    this.minCountPerSpecies = 1,
    this.maxCountPerSpecies = 3,
    this.groupingRequired = true,
  });

  factory PokitConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const PokitConfig();
    return PokitConfig(
      minSpecies: _num(j['minSpecies'], 2).round(),
      maxSpecies: _num(j['maxSpecies'], 4).round(),
      minCountPerSpecies: _num(j['minCountPerSpecies'], 1).round(),
      maxCountPerSpecies: _num(j['maxCountPerSpecies'], 3).round(),
      groupingRequired: j['groupingRequired'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'minSpecies': minSpecies,
        'maxSpecies': maxSpecies,
        'minCountPerSpecies': minCountPerSpecies,
        'maxCountPerSpecies': maxCountPerSpecies,
        'groupingRequired': groupingRequired,
      };
}

/// Один вид у раунді й кількість особин.
class PokitRoundItem {
  final PokitSpecies species;
  final int count;
  const PokitRoundItem(this.species, this.count);
}

class PokitMark {
  final bool rankOk, groupOk;
  const PokitMark(this.rankOk, this.groupOk);
  bool get ok => rankOk && groupOk;
}

class PokitCheck {
  final List<PokitMark> marks;
  final int correct, total;
  const PokitCheck(this.marks, this.correct, this.total);
  int get percent => total == 0 ? 0 : (correct * 100 / total).round();
}

/// Справжній Fisher–Yates.
List<T> pokitShuffle<T>(List<T> a, [Random? rng]) {
  final r = rng ?? Random();
  for (var i = a.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final t = a[i];
    a[i] = a[j];
    a[j] = t;
  }
  return a;
}

/// Раунд: N різних видів у межах конфігурації, у кожного — випадкова кількість.
List<PokitRoundItem> generatePokitRound(List<PokitSpecies> species, PokitConfig cfg, [Random? rng]) {
  final r = rng ?? Random();
  final pool = pokitShuffle(List.of(species), r);
  final lo = max(1, cfg.minSpecies), hi = max(lo, cfg.maxSpecies);
  final n = min(pool.length, lo + r.nextInt(hi - lo + 1));
  final cLo = max(1, cfg.minCountPerSpecies), cHi = max(cLo, cfg.maxCountPerSpecies);
  return [for (final sp in pool.take(n)) PokitRoundItem(sp, cLo + r.nextInt(cHi - cLo + 1))];
}

/// Правильний ряд: за pokitRank (зростання), однакові види підряд.
List<PokitSpecies> pokitCorrectOrder(List<PokitRoundItem> round) {
  final sorted = List.of(round)
    ..sort((a, b) {
      final c = a.species.pokitRank.compareTo(b.species.pokitRank);
      return c != 0 ? c : a.species.name.compareTo(b.species.name);
    });
  return [for (final it in sorted) for (var i = 0; i < it.count; i++) it.species];
}

/// Перевірка ряду (по одній тварині). Тварина зарахована, якщо (а) ранг її
/// виду дорівнює рангу, що має стояти на цьому місці (однаковий ранг —
/// взаємозамінні), і (б) за обов'язкового групування — її вид суцільним блоком.
PokitCheck checkPokitRow(List<PokitSpecies> row, List<PokitRoundItem> round, bool groupingRequired) {
  final expected = pokitCorrectOrder(round).map((s) => s.pokitRank).toList();
  final first = <String, int>{}, last = <String, int>{}, count = <String, int>{};
  for (var i = 0; i < row.length; i++) {
    final id = row[i].id;
    first.putIfAbsent(id, () => i);
    last[id] = i;
    count[id] = (count[id] ?? 0) + 1;
  }
  bool grouped(String id) => last[id]! - first[id]! + 1 == count[id];
  final marks = [
    for (var i = 0; i < row.length; i++)
      PokitMark(i < expected.length && row[i].pokitRank == expected[i], !groupingRequired || grouped(row[i].id)),
  ];
  return PokitCheck(marks, marks.where((m) => m.ok).length, row.length);
}

/// Запис журналу pokit_sessions (для «Моїх результатів»).
class PokitSession {
  final String docId;
  final String roundText;
  final int correct, total, percent;
  final DateTime? createdAt;

  const PokitSession({required this.docId, required this.roundText, required this.correct, required this.total, required this.percent, this.createdAt});

  factory PokitSession.fromDoc(String id, Map<String, dynamic> j) => PokitSession(
        docId: id,
        roundText: ((j['round'] as List?) ?? []).whereType<Map>().map((r) => '${r['count']}× ${r['speciesName']}').join(', '),
        correct: _num(j['correct']).round(),
        total: _num(j['total']).round(),
        percent: _num(j['percent']).round(),
        createdAt: (j['createdAt'] as Timestamp?)?.toDate(),
      );
}
