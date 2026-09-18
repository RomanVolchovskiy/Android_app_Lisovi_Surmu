import 'package:flutter/material.dart';

import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/screens/magic_horn_game_screen.dart';
import 'package:hunting_signals/screens/metronome_screen.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/signal_card.dart' show openSignalNotation;

/// Вкладка «Навчальні тренажери» на екрані навчання.
///
/// Внутрішні вкладки-фішки:
///  • «Примітивні ноти» — вибір сигналу відкриває його екран «Ноти»;
///  • «Чарівна сурма» — ритмічна гра для сигналів із графічними нотами.
class TrainersScreen extends StatefulWidget {
  const TrainersScreen({super.key});

  @override
  State<TrainersScreen> createState() => _TrainersScreenState();
}

class _TrainersScreenState extends State<TrainersScreen> {
  int _current = 0;
  List<HuntingSignal> _signals = [];
  bool _loading = true;

  static const _trainers = [
    (icon: Icons.music_note_rounded, label: 'Примітивні ноти'),
    (icon: Icons.sports_esports_rounded, label: 'Чарівна сурма'),
    (icon: Icons.timer_rounded, label: 'Метроном'),
  ];

  @override
  void initState() {
    super.initState();
    HuntingDataService.getAllSignals().then((list) {
      if (mounted) setState(() { _signals = list; _loading = false; });
    });
  }

  static bool _hasNotes(HuntingSignal s) =>
      (s.notationUrl?.isNotEmpty ?? false) ||
      (s.notationData?.isNotEmpty ?? false) ||
      (s.signalText?.isNotEmpty ?? false) ||
      (s.partitureUrl?.isNotEmpty ?? false);

  static bool _hasGraphicNotes(HuntingSignal s) => s.notationData?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Внутрішні вкладки ──
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: _trainers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = _trainers[i];
              final selected = i == _current;
              return ChoiceChip(
                avatar: Icon(t.icon, size: 18, color: selected ? HuntingTheme.primaryDark : Colors.grey[700]),
                label: Text(t.label),
                selected: selected,
                selectedColor: HuntingTheme.primaryColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: selected ? HuntingTheme.primaryDark : Colors.grey[700],
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _current = i),
              );
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_current == 0 ? _primitiveNotes() : _current == 1 ? _magicHorn() : _metronome()),
        ),
      ],
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      );

  Widget _groupTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _row(HuntingSignal s, {required bool enabled, required Widget leading, required String subtitle, required Widget trailing, required VoidCallback onTap}) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: ListTile(
          leading: leading,
          title: Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _primitiveNotes() {
    if (_signals.isEmpty) return _empty(Icons.music_note_rounded, 'Сигнали ще не додані');
    final withNotes = _signals.where(_hasNotes).toList();
    final without = _signals.where((s) => !_hasNotes(s)).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _hint('Оберіть сигнал — відкриються його ноти, аудіо до нот і графічне відображення для тренування.'),
        for (final s in withNotes)
          _row(s,
              enabled: true,
              leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icons/icon1.png', width: 40, height: 40, fit: BoxFit.cover)),
              subtitle: s.category,
              trailing: const Icon(Icons.music_note_rounded, color: HuntingTheme.primaryColor),
              onTap: () => openSignalNotation(context, s)),
        if (without.isNotEmpty) ...[
          _groupTitle('Без нот'),
          for (final s in without)
            _row(s,
                enabled: false,
                leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icons/icon1.png', width: 40, height: 40, fit: BoxFit.cover)),
                subtitle: s.category,
                trailing: Text('Ноти не додані', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ноти не додані для цього сигналу')))),
        ],
      ],
    );
  }

  Widget _magicHorn() {
    if (_signals.isEmpty) return _empty(Icons.sports_esports_rounded, 'Сигнали ще не додані');
    final playable = _signals.where(_hasGraphicNotes).toList();
    final rest = _signals.where((s) => !_hasGraphicNotes(s)).toList();
    Widget horn() => Container(
          width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFD4A017).withValues(alpha: .18), borderRadius: BorderRadius.circular(10)),
          child: const Text('📯', style: TextStyle(fontSize: 22)),
        );
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _hint('Гра на кшталт «Piano Tiles»: ноти сигналу летять доріжками — влучайте в них у ритмі, і сурма заграє мелодію.'),
        if (playable.isEmpty)
          _hint('Поки жоден сигнал не має графічних нот.')
        else
          for (final s in playable)
            _row(s,
                enabled: true,
                leading: horn(),
                subtitle: '${s.notationData!.where((n) => (n['t'] ?? 'n') == 'n').length} нот · ${s.notationTempo ?? 90} BPM',
                trailing: const Icon(Icons.play_arrow_rounded, color: HuntingTheme.primaryColor),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MagicHornGameScreen(signal: s)))),
        if (rest.isNotEmpty) ...[
          _groupTitle('Без графічних нот'),
          for (final s in rest)
            _row(s,
                enabled: false,
                leading: horn(),
                subtitle: 'Немає графічних нот',
                trailing: const SizedBox.shrink(),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Для гри потрібне графічне відображення нот — додайте його в адмін-панелі')))),
        ],
      ],
    );
  }

  Widget _metronome() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _hint('Метроном зі звуком мисливського рога: темп 30–250 BPM, розміри від 1/4 до 12/8, підрозділи долі, акценти, відстукування темпу.'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: ListTile(
            leading: Container(
              width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFD4A017).withValues(alpha: .18), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.timer_rounded, color: Color(0xFFD4A017)),
            ),
            title: const Text('Відкрити метроном', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Сильна доля — СОЛЬ2, слабкі — ДО2, підрозділи — ДО', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.play_arrow_rounded, color: HuntingTheme.primaryColor),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MetronomeScreen())),
          ),
        ),
      ],
    );
  }

  Widget _empty(IconData icon, String text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ]),
      );
}
