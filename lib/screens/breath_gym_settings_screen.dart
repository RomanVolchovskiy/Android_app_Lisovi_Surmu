import 'package:flutter/material.dart';

import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/services/breath_gym_prefs.dart';
import 'package:hunting_signals/services/breath_gym_sound.dart';
import 'package:hunting_signals/services/breath_gym_storage.dart';

/// Налаштування тренажера: звук, вібрація, голос, скидання даних.
class BreathGymSettingsScreen extends StatefulWidget {
  const BreathGymSettingsScreen({super.key});

  @override
  State<BreathGymSettingsScreen> createState() => _BreathGymSettingsScreenState();
}

class _BreathGymSettingsScreenState extends State<BreathGymSettingsScreen> {
  /// null — ще перевіряємо, чи є український голос.
  bool? _voiceAvailable;

  @override
  void initState() {
    super.initState();
    BreathGymPrefs.load().then((_) {
      if (mounted) setState(() {});
    });
    BreathGymVoice.available().then((ok) async {
      // Голос зник (наприклад, видалили пакет) — вимикаємо підказки.
      if (!ok && BreathGymPrefs.settings.value.voice) {
        await BreathGymPrefs.save(BreathGymPrefs.settings.value.copyWith(voice: false));
      }
      if (mounted) setState(() => _voiceAvailable = ok);
    });
  }

  void _update(BreathGymSettings s) {
    BreathGymPrefs.save(s);
    setState(() {});
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(BgStrings.clearHistory),
        content: const Text(BgStrings.clearHistoryBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(BgStrings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(BgStrings.clear)),
        ],
      ),
    );
    if (ok != true) return;
    await BreathGymStorage.clearAll();
    if (mounted) _snack(BgStrings.clearHistoryDone);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = BreathGymPrefs.settings.value;
    final heading = theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold);
    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(header: true, child: Text(t, style: heading)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(BgStrings.settingsTitle)),
      body: ListView(
        children: [
          header(BgStrings.soundSection),
          SwitchListTile(
            title: const Text(BgStrings.metronome),
            subtitle: const Text(BgStrings.metronomeHint),
            value: s.metronome,
            onChanged: (v) => _update(s.copyWith(metronome: v)),
          ),
          ListTile(
            enabled: s.metronome,
            title: const Text(BgStrings.volume),
            subtitle: Slider(
              value: s.volume,
              divisions: 10,
              label: '${(s.volume * 100).round()}%',
              semanticFormatterCallback: (v) => '${BgStrings.volume} ${(v * 100).round()}%',
              onChanged: s.metronome ? (v) => _update(s.copyWith(volume: v)) : null,
            ),
          ),
          SwitchListTile(
            title: const Text(BgStrings.vibration),
            value: s.vibration,
            onChanged: (v) => _update(s.copyWith(vibration: v)),
          ),
          SwitchListTile(
            title: const Text(BgStrings.voice),
            subtitle: Text(_voiceAvailable == false ? BgStrings.voiceUnavailable : BgStrings.voiceHint),
            value: s.voice && _voiceAvailable == true,
            onChanged: _voiceAvailable == true ? (v) => _update(s.copyWith(voice: v)) : null,
          ),
          if (_voiceAvailable == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => BreathGymVoice.say(BgStrings.voiceTestPhrase),
                  icon: const Icon(Icons.record_voice_over_outlined),
                  label: const Text(BgStrings.voiceTest),
                ),
              ),
            ),
          header(BgStrings.dataSection),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text(BgStrings.resetExercises),
            onTap: () async {
              await BreathGymPrefs.resetExercises();
              if (mounted) _snack(BgStrings.resetExercisesDone);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(BgStrings.clearHistory, style: TextStyle(color: theme.colorScheme.error)),
            onTap: _clearHistory,
          ),
        ],
      ),
    );
  }
}
