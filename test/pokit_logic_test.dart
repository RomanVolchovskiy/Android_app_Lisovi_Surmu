import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hunting_signals/models/pokit_models.dart';

// Логіка тренажера «Покіт»: ті самі випадки, що перевірено для сайту.
void main() {
  const k = PokitSpecies(id: 'k', name: 'Кабан', pokitRank: 10);
  const l = PokitSpecies(id: 'l', name: 'Лисиця', pokitRank: 20);
  const z = PokitSpecies(id: 'z', name: 'Заєць', pokitRank: 20);
  const round = [PokitRoundItem(k, 2), PokitRoundItem(l, 1), PokitRoundItem(z, 2)];
  List<bool> oks(List<PokitSpecies> row, [bool g = true]) => checkPokitRow(row, round, g).marks.map((m) => m.ok).toList();

  test('правильний ряд — за рангом, однакові види підряд', () {
    expect(pokitCorrectOrder(round).map((s) => s.pokitRank), [10, 10, 20, 20, 20]);
  });
  test('ідеальний ряд — 100%', () => expect(checkPokitRow([k, k, l, z, z], round, true).percent, 100));
  test('види однакового рангу взаємозамінні', () => expect(checkPokitRow([k, k, z, z, l], round, true).percent, 100));
  test('розірвана група: позначено всі тварини виду', () {
    expect(oks([k, k, z, l, z]), [true, true, false, true, false]);
    expect(oks([k, l, k, z, z]), [false, false, false, true, true]);
  });
  test('без обов’язкового групування — лише порядок', () => expect(checkPokitRow([k, k, z, l, z], round, false).percent, 100));
  test('обернений ряд — частковий бал', () => expect(checkPokitRow([z, z, l, k, k], round, true).percent, 20));
  test('порожній ряд — 0%', () => expect(checkPokitRow([], round, true).percent, 0));

  test('раунд у межах налаштувань', () {
    final sp = [k, l, z, const PokitSpecies(id: 'v', name: 'Вовк', pokitRank: 5), const PokitSpecies(id: 'x', name: 'X', pokitRank: 1)];
    const cfg = PokitConfig(minSpecies: 2, maxSpecies: 4, minCountPerSpecies: 1, maxCountPerSpecies: 3);
    final rng = Random(1);
    for (var i = 0; i < 2000; i++) {
      final r = generatePokitRound(sp, cfg, rng);
      expect(r.length, inInclusiveRange(2, 4));
      expect(r.every((x) => x.count >= 1 && x.count <= 3), isTrue);
      expect(r.map((x) => x.species.id).toSet().length, r.length);
    }
    expect(generatePokitRound([k, l], const PokitConfig(minSpecies: 2, maxSpecies: 9)).length, 2);
  });

  test('перемішування рівномірне', () {
    final c = [0, 0, 0, 0], rng = Random(7);
    for (var i = 0; i < 40000; i++) {
      c[pokitShuffle([0, 1, 2, 3], rng).first]++;
    }
    for (final x in c) {
      expect((x / 40000 - .25).abs(), lessThan(.02));
    }
  });
}
