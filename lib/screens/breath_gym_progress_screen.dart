import 'dart:math';

import 'package:flutter/material.dart';

import 'package:hunting_signals/data/breath_gym_catalog.dart';
import 'package:hunting_signals/data/breath_gym_strings.dart';
import 'package:hunting_signals/services/breath_gym_stats.dart';
import 'package:hunting_signals/services/breath_gym_storage.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

/// Вправи з рекордами видиху на графіку.
const _recordExercises = ['hiss_exhale', 'candle', 'paper_wall'];

/// Прогрес: тиждень, серія днів, графіки рекордів, історія.
class BreathGymProgressScreen extends StatefulWidget {
  const BreathGymProgressScreen({super.key});

  @override
  State<BreathGymProgressScreen> createState() => _BreathGymProgressScreenState();
}

class _BreathGymProgressScreenState extends State<BreathGymProgressScreen> {
  List<BreathSessionLog>? _sessions;
  List<BreathAttempt> _attempts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Future.wait([BreathGymStorage.sessions(), BreathGymStorage.allAttempts()]);
    if (!mounted) return;
    setState(() {
      _sessions = r[0] as List<BreathSessionLog>;
      _attempts = r[1] as List<BreathAttempt>;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(title: const Text(BgStrings.progress)),
      body: sessions == null ? const Center(child: CircularProgressIndicator()) : _body(context, sessions),
    );
  }

  Widget _body(BuildContext context, List<BreathSessionLog> sessions) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final week = weekCounts(sessions, now);
    final weekDays = week.where((c) => c > 0).length;
    final streak = currentStreak(sessions, now);
    final best = longestStreak(sessions);
    final heading = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final history = sessions.where((s) => s.completed).toList()..sort((a, b) => b.at.compareTo(a.at));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: BgStrings.thisWeek,
                value: BgStrings.exercisesCount(week.fold(0, (a, b) => a + b)),
                caption: BgStrings.days(weekDays),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: BgStrings.streak,
                value: BgStrings.days(streak),
                caption: '${BgStrings.bestStreak}: ${BgStrings.days(best)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          label:
              '${BgStrings.thisWeek}: '
              '${[for (var i = 0; i < 7; i++) '${BgStrings.weekdays[i]} ${week[i]}'].join(', ')}',
          excludeSemantics: true,
          child: SizedBox(
            height: 140,
            child: _WeekBars(counts: week, today: now.weekday - 1),
          ),
        ),
        const SizedBox(height: 24),
        Semantics(header: true, child: Text(BgStrings.records, style: heading)),
        for (final id in _recordExercises) _RecordCard(exerciseId: id, attempts: chartPoints(_attempts, id)),
        const SizedBox(height: 24),
        Semantics(header: true, child: Text(BgStrings.history, style: heading)),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(BgStrings.noHistory, style: theme.textTheme.bodyMedium),
          ),
        ...history
            .take(30)
            .map(
              (s) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline, size: 20),
                title: Text(breathGymById[s.exerciseId]?.title ?? s.exerciseId),
                subtitle: Text(BgStrings.duration(s.seconds)),
                trailing: Text(BgStrings.dateTime(s.at)),
              ),
            ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value, caption;
  const _StatTile({required this.label, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(caption, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Стовпчики «вправ за день» пн–нд. Одна серія — без легенди; значення
/// підписані над ненульовими стовпчиками.
class _WeekBars extends StatelessWidget {
  final List<int> counts;
  final int today;
  const _WeekBars({required this.counts, required this.today});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: _WeekBarsPainter(
        counts: counts,
        today: today,
        bar: BreathGymPalette.of(context).exhale,
        ink: theme.colorScheme.onSurface,
        muted: theme.colorScheme.onSurfaceVariant,
        grid: theme.colorScheme.outlineVariant,
      ),
    );
  }
}

class _WeekBarsPainter extends CustomPainter {
  final List<int> counts;
  final int today;
  final Color bar, ink, muted, grid;
  _WeekBarsPainter({
    required this.counts,
    required this.today,
    required this.bar,
    required this.ink,
    required this.muted,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 20.0, valueH = 18.0;
    final plotH = size.height - labelH - valueH;
    final baseY = valueH + plotH;
    final maxV = max(1, counts.fold(0, max));
    final slot = size.width / 7;
    final barW = min(28.0, slot * 0.55);

    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    for (var i = 0; i < 7; i++) {
      final cx = slot * i + slot / 2;
      final v = counts[i];
      if (v > 0) {
        final h = max(4.0, plotH * v / maxV);
        final r = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, baseY - h, barW, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(r, Paint()..color = bar);
        _text(canvas, '$v', Offset(cx, baseY - h - 2), ink, 12, FontWeight.w600, above: true);
      }
      _text(
        canvas,
        BgStrings.weekdays[i],
        Offset(cx, baseY + 4),
        i == today ? ink : muted,
        12,
        i == today ? FontWeight.bold : FontWeight.normal,
      );
    }
  }

  void _text(Canvas c, String s, Offset at, Color color, double size, FontWeight w, {bool above = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, fontWeight: w),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(at.dx - tp.width / 2, above ? at.dy - tp.height : at.dy));
  }

  @override
  bool shouldRepaint(_WeekBarsPainter old) => old.counts != counts || old.bar != bar || old.today != today;
}

/// Картка рекорду вправи з лінійним графіком спроб. Торкання — найближча
/// спроба (значення й дата над графіком).
class _RecordCard extends StatefulWidget {
  final String exerciseId;
  final List<BreathAttempt> attempts;
  const _RecordCard({required this.exerciseId, required this.attempts});

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pts = widget.attempts;
    final title = breathGymById[widget.exerciseId]?.title ?? widget.exerciseId;
    final record = bestOf(pts);
    final sel = _selected != null && _selected! < pts.length ? pts[_selected!] : null;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (record > 0) ...[
                  const Icon(Icons.emoji_events_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(BgStrings.sec(record), style: theme.textTheme.titleSmall),
                ],
              ],
            ),
            if (pts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(BgStrings.noAttempts, style: theme.textTheme.bodySmall),
              )
            else ...[
              Text(
                sel != null
                    ? '${BgStrings.sec(sel.seconds)} · ${BgStrings.dateTime(sel.at)}'
                    : '${BgStrings.attemptsCount(pts.length)} · ${BgStrings.tapPoint}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Semantics(
                label: '$title: ${pts.map((a) => BgStrings.sec(a.seconds)).join(', ')}',
                excludeSemantics: true,
                child: LayoutBuilder(
                  builder: (context, box) {
                    const height = 140.0;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => setState(
                        () => _selected = _RecordPainter.nearest(pts.length, box.maxWidth, d.localPosition.dx),
                      ),
                      child: SizedBox(
                        width: box.maxWidth,
                        height: height,
                        child: CustomPaint(
                          painter: _RecordPainter(
                            values: [for (final a in pts) a.seconds],
                            selected: _selected,
                            line: BreathGymPalette.of(context).exhale,
                            surface: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
                            ink: theme.colorScheme.onSurface,
                            muted: theme.colorScheme.onSurfaceVariant,
                            grid: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordPainter extends CustomPainter {
  static const _left = 36.0, _right = 12.0, _top = 18.0, _bottom = 6.0;

  final List<double> values;
  final int? selected;
  final Color line, surface, ink, muted, grid;
  _RecordPainter({
    required this.values,
    required this.selected,
    required this.line,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.grid,
  });

  static double _x(int i, int n, double width) =>
      n == 1 ? _left + (width - _left - _right) / 2 : _left + (width - _left - _right) * i / (n - 1);

  /// Індекс точки, найближчої до дотику по горизонталі.
  static int nearest(int n, double width, double dx) {
    var best = 0;
    for (var i = 1; i < n; i++) {
      if ((_x(i, n, width) - dx).abs() < (_x(best, n, width) - dx).abs()) best = i;
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    final maxV = values.fold(0.0, max);
    final step = _niceStep(maxV);
    final top = max(step, (maxV / step).ceil() * step);
    final plotH = size.height - _top - _bottom;
    double y(double v) => _top + plotH * (1 - v / top);

    // Сітка: 0, крок, … — бліда, з підписами секунд ліворуч.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = 0.0; v <= top + 1e-9; v += step) {
      canvas.drawLine(Offset(_left, y(v)), Offset(size.width - _right, y(v)), gridPaint);
      _text(canvas, v.round().toString(), Offset(_left - 6, y(v)), muted, 11, alignRight: true);
    }

    final pts = [for (var i = 0; i < n; i++) Offset(_x(i, n, size.width), y(values[i]))];
    if (n > 1) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Маркери з кільцем кольору поверхні; рекорд і вибрана — більші.
    final recordIdx = values.indexOf(maxV);
    for (var i = 0; i < n; i++) {
      final big = i == recordIdx || i == selected;
      final r = big ? 6.0 : 4.0;
      canvas.drawCircle(pts[i], r + 2, Paint()..color = surface);
      canvas.drawCircle(pts[i], r, Paint()..color = line);
    }
    if (selected != null && selected! < n) {
      canvas.drawLine(
        Offset(pts[selected!].dx, _top),
        Offset(pts[selected!].dx, size.height - _bottom),
        Paint()
          ..color = muted
          ..strokeWidth = 1,
      );
    }
    // Підпис лише в рекорду.
    _text(
      canvas,
      BgStrings.sec(maxV),
      pts[recordIdx].translate(0, -10),
      ink,
      12,
      weight: FontWeight.w600,
      above: true,
      clampWidth: size.width,
    );
  }

  static double _niceStep(double maxV) {
    if (maxV <= 10) return 2;
    if (maxV <= 25) return 5;
    if (maxV <= 60) return 10;
    return 20;
  }

  void _text(
    Canvas c,
    String s,
    Offset at,
    Color color,
    double size, {
    FontWeight weight = FontWeight.normal,
    bool alignRight = false,
    bool above = false,
    double? clampWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = alignRight ? at.dx - tp.width : at.dx - tp.width / 2;
    if (clampWidth != null) dx = dx.clamp(0, clampWidth - tp.width);
    final dy = above ? max(0.0, at.dy - tp.height) : at.dy - tp.height / 2;
    tp.paint(c, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_RecordPainter old) => old.values != values || old.selected != selected || old.line != line;
}
