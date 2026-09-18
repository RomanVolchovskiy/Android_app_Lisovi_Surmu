import 'package:flutter/material.dart';
import 'package:hunting_signals/utils/local_image_io.dart'
    if (dart.library.html) 'package:hunting_signals/utils/local_image_web.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ── CONSTANTS ──────────────────────────────────────────────────────────────────

const _rowH   = 40.0;
const _rowGap = 4.0;   // gap between rows
const _noteW  = 62.0;  // horizontal slot per item
const _sqSz   = 9.0;
const _sqMar  = 1.0;
const _labelW = 54.0;  // fixed width for pitch labels

// Pitch labels: index 0 = top row (highest pitch), 4 = bottom (lowest)
const _pitchLabels = ['СОЛЬ2', 'МІ2', 'ДО2', 'СОЛЬ', 'ДО'];

// Item types
const _typeNote   = 'n';
const _typeBreath = 'b';
const _typePause  = 'pa';

// Filled squares per duration: whole=0, half=4, quarter=3, eighth=2, sixteenth=1
const _filledSquares = [0, 4, 3, 2, 1];
const _durationLabels = ['Ціла', 'Половинна', 'Четвертна', 'Восьма', '1/16'];

// Total staff content height (5 rows + 4 gaps between them)
double get _staffH => 5 * _rowH + 4 * _rowGap;

// Y-position of top edge of row [pitch]
double _rowTop(int pitch) => pitch * (_rowH + _rowGap);

// ── EDITOR WIDGET ──────────────────────────────────────────────────────────────

class NotationEditorWidget extends StatefulWidget {
  final List<Map<String, dynamic>> initialNotes;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const NotationEditorWidget({
    super.key,
    required this.initialNotes,
    required this.onChanged,
  });

  @override
  State<NotationEditorWidget> createState() => _NotationEditorState();
}

class _NotationEditorState extends State<NotationEditorWidget> {
  late List<Map<String, dynamic>> _items;
  int? _selectedPitch;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.initialNotes);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged(List.from(_items));

  void _selectPitch(int p) => setState(() => _selectedPitch = p);

  // Add a regular note (requires pitch selected first)
  void _addNote(int duration) {
    if (_selectedPitch == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Спочатку натисніть на один із рядків нотного стану'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    setState(() {
      _items.add({'t': _typeNote, 'p': _selectedPitch!, 'd': duration});
      _selectedPitch = null;
    });
    _notify();
    _scrollToEnd();
  }

  // Add a breath mark (no pitch needed)
  void _addBreath() {
    setState(() {
      _items.add({'t': _typeBreath});
      _selectedPitch = null;
    });
    _notify();
    _scrollToEnd();
  }

  // Add a pause mark (no pitch needed)
  void _addPause() {
    setState(() {
      _items.add({'t': _typePause});
      _selectedPitch = null;
    });
    _notify();
    _scrollToEnd();
  }

  void _undo() {
    if (_items.isEmpty) return;
    setState(() => _items.removeLast());
    _notify();
  }

  void _clear() {
    setState(() { _items.clear(); _selectedPitch = null; });
    _notify();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instructions
        Text(
          'Крок 1: оберіть рядок (висота тону). '
          'Крок 2: оберіть тривалість або знак нижче.',
          style: TextStyle(fontSize: 11, color: Colors.brown[600], fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),
        _buildStaff(),
        const SizedBox(height: 12),
        _buildButtons(),
        const SizedBox(height: 4),
        // Status + action row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: _selectedPitch != null
                  ? Text(
                      'Обрано: ${_pitchLabels[_selectedPitch!]} · Натисніть тривалість',
                      style: TextStyle(
                          color: Colors.brown[700], fontSize: 11, fontStyle: FontStyle.italic),
                    )
                  : Text(
                      '${_items.length} елементів',
                      style: TextStyle(color: Colors.brown[400], fontSize: 11),
                    ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _items.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Скасувати', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: _items.isEmpty ? null : _clear,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Очистити', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Staff ──────────────────────────────────────────────────────────────────

  Widget _buildStaff() {
    final cols = (_items.isEmpty ? 4 : _items.length + 2);
    final contentW = (cols * _noteW).clamp(240.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.brown[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown[200]!),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed pitch labels
          SizedBox(
            width: _labelW,
            height: _staffH,
            child: Column(
              children: List.generate(5, (i) => SizedBox(
                height: _rowH + (i < 4 ? _rowGap : 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _pitchLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[800],
                    ),
                  ),
                ),
              )),
            ),
          ),
          // Scrollable staff content
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _scroll,
              child: SizedBox(
                width: contentW,
                height: _staffH,
                child: Stack(
                  children: [
                    // Background rows (tap for pitch selection)
                    Column(
                      children: List.generate(5, (p) => _buildRow(p, contentW)),
                    ),
                    // Notes and marks
                    ..._buildItemWidgets(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int pitch, double width) {
    final selected = _selectedPitch == pitch;
    return GestureDetector(
      onTap: () => _selectPitch(pitch),
      child: Container(
        width: width,
        height: _rowH,
        margin: EdgeInsets.only(bottom: pitch < 4 ? _rowGap : 0),
        decoration: BoxDecoration(
          color: selected ? Colors.brown[200] : Colors.grey[350],
          borderRadius: BorderRadius.circular(5),
          border: selected ? Border.all(color: Colors.brown[700]!, width: 2) : null,
        ),
      ),
    );
  }

  List<Widget> _buildItemWidgets() {
    final widgets = <Widget>[];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final t = item['t'] ?? _typeNote;
      final x = i * _noteW;

      if (t == _typeNote) {
        final pitch = (item['p'] as num).toInt();
        final duration = (item['d'] as num).toInt();
        widgets.add(Positioned(
          left: x + 8,
          top: _rowTop(pitch),
          height: _rowH,
          child: Center(child: buildSquaresWidget(duration, _sqSz)),
        ));
      } else if (t == _typeBreath) {
        // Thin vertical line through all rows
        widgets.add(Positioned(
          left: x + _noteW / 2 - 1,
          top: 0,
          child: Container(width: 1.5, height: _staffH, color: Colors.brown[800]),
        ));
      } else if (t == _typePause) {
        // Two thick vertical lines through all rows
        widgets.add(Positioned(
          left: x + _noteW / 2 - 7,
          top: 0,
          child: SizedBox(
            height: _staffH,
            child: Row(
              children: [
                Container(width: 3.5, height: _staffH, color: Colors.brown[900]),
                const SizedBox(width: 5),
                Container(width: 3.5, height: _staffH, color: Colors.brown[900]),
              ],
            ),
          ),
        ));
      }
    }
    return widgets;
  }

  // ── Buttons ────────────────────────────────────────────────────────────────

  Widget _buildButtons() {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        // 5 duration buttons
        ...List.generate(5, (i) => _DurationBtn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildSquaresWidget(i, 11),
              const SizedBox(height: 4),
              Text(_durationLabels[i],
                  style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
          onTap: () => _addNote(i),
        )),
        // Divider
        Container(
          width: 1,
          height: 44,
          color: Colors.brown[300],
          margin: const EdgeInsets.symmetric(horizontal: 2),
        ),
        // Breath button: one vertical line
        _DurationBtn(
          tooltip: 'Вдих (продовження)',
          onTap: _addBreath,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 2, height: 20, color: Colors.white),
              const SizedBox(height: 4),
              const Text('Вдих', style: TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
        ),
        // Pause button: two thick vertical lines
        _DurationBtn(
          tooltip: 'Пауза',
          onTap: _addPause,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 4, height: 20, color: Colors.white),
                  const SizedBox(width: 5),
                  Container(width: 4, height: 20, color: Colors.white),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Пауза', style: TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── DISPLAY WIDGET (viewer) ────────────────────────────────────────────────────

class NotationDisplayWidget extends StatefulWidget {
  final List<Map<String, dynamic>> notes;
  final int currentNoteIndex;          // -1 = none highlighted
  final ScrollController? scrollController;

  const NotationDisplayWidget({
    super.key,
    required this.notes,
    this.currentNoteIndex = -1,
    this.scrollController,
  });

  @override
  State<NotationDisplayWidget> createState() => _NotationDisplayWidgetState();
}

class _NotationDisplayWidgetState extends State<NotationDisplayWidget> {
  final ScrollController _internalScroll = ScrollController();
  ScrollController get _scroll => widget.scrollController ?? _internalScroll;

  @override
  void dispose() {
    _internalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) return const SizedBox.shrink();
    final cols = widget.notes.length + 2;
    final staffW = (cols * _noteW).clamp(240.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Staff display ──
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF243328),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4A6741)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.grid_on_rounded, color: Color(0xFFD4A017), size: 15),
                SizedBox(width: 8),
                Text('Графічне відображення нот',
                    style: TextStyle(
                        color: Color(0xFFD4A017),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _scroll,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pitch labels (fixed)
                    SizedBox(
                      width: _labelW,
                      height: _staffH,
                      child: Column(
                        children: List.generate(5, (i) => SizedBox(
                          height: _rowH + (i < 4 ? _rowGap : 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_pitchLabels[i],
                                style: const TextStyle(
                                    color: Color(0xFFCCDDCC),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        )),
                      ),
                    ),
                    // Staff with notes + cursor
                    SizedBox(
                      width: staffW,
                      height: _staffH,
                      child: Stack(
                        children: [
                          // Background rows (white staff lines)
                          Column(
                            children: List.generate(5, (p) => Container(
                              width: staffW,
                              height: _rowH,
                              margin: EdgeInsets.only(bottom: p < 4 ? _rowGap : 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )),
                          ),
                          // Current note highlight
                          if (widget.currentNoteIndex >= 0 &&
                              widget.currentNoteIndex < widget.notes.length)
                            Positioned(
                              left: widget.currentNoteIndex * _noteW,
                              top: 0,
                              child: Container(
                                width: _noteW,
                                height: _staffH,
                                color: const Color(0xFFD4A017).withValues(alpha: 0.25),
                              ),
                            ),
                          // Notes and marks
                          ..._buildDisplayItems(staffW),
                          // Cursor line on active note
                          if (widget.currentNoteIndex >= 0 &&
                              widget.currentNoteIndex < widget.notes.length)
                            Positioned(
                              left: widget.currentNoteIndex * _noteW,
                              top: 0,
                              child: Container(
                                width: 2.5,
                                height: _staffH,
                                color: const Color(0xFFD4A017),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Legend ──
        _buildLegend(),
      ],
    );
  }

  List<Widget> _buildDisplayItems(double staffW) {
    final widgets = <Widget>[];
    for (int i = 0; i < widget.notes.length; i++) {
      final item = widget.notes[i];
      final t = item['t'] ?? _typeNote;
      final x = i * _noteW;

      if (t == _typeNote) {
        final pitch = (item['p'] as num).toInt();
        final duration = (item['d'] as num).toInt();
        widgets.add(Positioned(
          left: x + 8,
          top: _rowTop(pitch),
          height: _rowH,
          child: Center(child: buildSquaresWidget(duration, _sqSz)),
        ));
      } else if (t == _typeBreath) {
        widgets.add(Positioned(
          left: x + _noteW / 2 - 1,
          top: 0,
          child: Container(width: 1.5, height: _staffH, color: Colors.black),
        ));
      } else if (t == _typePause) {
        widgets.add(Positioned(
          left: x + _noteW / 2 - 7,
          top: 0,
          child: SizedBox(
            height: _staffH,
            child: Row(
              children: [
                Container(width: 4, height: _staffH, color: Colors.black),
                const SizedBox(width: 5),
                Container(width: 4, height: _staffH, color: Colors.black),
              ],
            ),
          ),
        ));
      }
    }
    return widgets;
  }

  Widget _buildLegend() {
    const cardColor = Color(0xFF1C2B1E);
    const borderColor = Color(0xFF4A6741);
    const labelStyle = TextStyle(color: Color(0xFFCCDDCC), fontSize: 11);
    const titleStyle = TextStyle(
        color: Color(0xFFD4A017), fontWeight: FontWeight.w700, fontSize: 12);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, color: Color(0xFFD4A017), size: 15),
            SizedBox(width: 8),
            Text('Умовні позначення', style: titleStyle),
          ]),
          const SizedBox(height: 10),

          // Pitch rows
          const Text('Висота тону (рядки нотного стану):', style: TextStyle(color: Color(0xFF8EAB8E), fontSize: 11)),
          const SizedBox(height: 6),
          ...List.generate(5, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Container(
                width: 40, height: 14,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Text(_pitchLabels[i], style: labelStyle),
              const SizedBox(width: 6),
              Text(
                _pitchDescription(i),
                style: const TextStyle(color: Color(0xFF8EAB8E), fontSize: 10),
              ),
            ]),
          )),
          const SizedBox(height: 10),

          // Durations
          const Text('Тривалість ноти:', style: TextStyle(color: Color(0xFF8EAB8E), fontSize: 11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: List.generate(5, (i) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildSquaresWidget(i, 9),
                const SizedBox(width: 6),
                Text(_durationLabels[i], style: labelStyle),
              ],
            )),
          ),
          const SizedBox(height: 10),

          // Special marks
          const Text('Спеціальні знаки:', style: TextStyle(color: Color(0xFF8EAB8E), fontSize: 11)),
          const SizedBox(height: 6),
          Row(children: [
            Container(width: 2, height: 24, color: const Color(0xFFD4A017)),
            const SizedBox(width: 12),
            const Text('Вдихнути повітря для наступної ноти', style: labelStyle),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Container(width: 4, height: 24, color: const Color(0xFFD4A017)),
            const SizedBox(width: 5),
            Container(width: 4, height: 24, color: const Color(0xFFD4A017)),
            const SizedBox(width: 12),
            const Text('Пауза', style: labelStyle),
          ]),
        ],
      ),
    );
  }

  static String _pitchDescription(int pitch) {
    const desc = ['(п\'ята лінія)', '(четверта лінія)', '(третя лінія)', '(друга лінія)', '(перша лінія)'];
    return desc[pitch];
  }
}

// ── HELPER BUTTON WIDGET ───────────────────────────────────────────────────────

class _DurationBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;

  const _DurationBtn({required this.child, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.brown[700],
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

// ── SHARED HELPERS ─────────────────────────────────────────────────────────────

Widget buildSquaresWidget(int duration, double size) {
  final f = _filledSquares[duration];
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: _sqMar),
      decoration: BoxDecoration(
        color: i < f ? Colors.black : Colors.transparent,
        border: Border.all(color: Colors.black, width: 1),
      ),
    )),
  );
}

Widget buildNotationImage(String? url) {
  if (url == null || url.isEmpty) return const SizedBox.shrink();
  if (url.startsWith('assets/')) return Image.asset(url, fit: BoxFit.contain);
  // Локальний шлях існує лише на мобільних; у браузері localImage повертає
  // порожнє місце (див. utils/local_image_web.dart) замість падіння.
  if (url.startsWith('/')) return localImage(url);
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.contain,
    placeholder: (_, __) =>
        const Center(child: CircularProgressIndicator(color: Colors.white)),
    errorWidget: (_, __, err) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Помилка завантаження:\n$err',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center),
      ),
    ),
  );
}
