import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/notation_editor.dart';

const _kPassword = '2505';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPassword());
  }

  Future<void> _askPassword() async {
    final ok = await _showPasswordDialog(context);
    if (mounted) setState(() => _unlocked = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Розділ захищено паролем',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _askPassword,
              icon: const Icon(Icons.key),
              label: const Text('Ввести пароль'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HuntingTheme.primaryDark,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<HuntingSignal>>(
      stream: HuntingDataService.signalsStream(),
      builder: (context, snapshot) {
        final signals = (snapshot.data ?? [])
            .where((s) => s.notationUrl != null && s.notationUrl!.isNotEmpty)
            .toList();

        if (signals.isEmpty) {
          return const Center(
            child: Text('Немає сигналів з нотами',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          itemCount: signals.length,
          itemBuilder: (context, index) {
            final signal = signals[index];
            return _NoteCard(signal: signal);
          },
        );
      },
    );
  }
}

// ── Картка з нотами одного сигналу ─────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final HuntingSignal signal;
  const _NoteCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final image = buildNotationImage(signal.notationUrl);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: HuntingTheme.primaryDark,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    signal.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Кнопка повноекранного режиму
                IconButton(
                  onPressed: () => _openFullscreen(context, image),
                  icon: const Icon(Icons.fullscreen,
                      color: Colors.white70, size: 26),
                  tooltip: 'Повноекранний режим',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Зображення нот
          GestureDetector(
            onTap: () => _openFullscreen(context, image),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120),
              color: const Color(0xFFF4EFE4),
              padding: const EdgeInsets.all(8),
              child: image,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context, Widget image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenNoteScreen(
          title: signal.name,
          child: image,
        ),
      ),
    );
  }
}

// ── Повноекранний переглядач нот ────────────────────────────────────────────

class _FullscreenNoteScreen extends StatefulWidget {
  final String title;
  final Widget child;
  const _FullscreenNoteScreen({required this.title, required this.child});

  @override
  State<_FullscreenNoteScreen> createState() => _FullscreenNoteScreenState();
}

class _FullscreenNoteScreenState extends State<_FullscreenNoteScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 8.0,
              child: Center(child: widget.child),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Діалог паролю ───────────────────────────────────────────────────────────

Future<bool> _showPasswordDialog(BuildContext context) async {
  final controller = TextEditingController();
  bool wrong = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock, color: Colors.amber),
              SizedBox(width: 8),
              Text('Захищений розділ'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Введіть пароль для доступу до нот:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Пароль',
                  border: const OutlineInputBorder(),
                  errorText: wrong ? 'Невірний пароль' : null,
                ),
                onSubmitted: (_) {
                  if (controller.text == _kPassword) {
                    Navigator.pop(ctx, true);
                  } else {
                    setS(() => wrong = true);
                    controller.clear();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HuntingTheme.primaryDark,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (controller.text == _kPassword) {
                  Navigator.pop(ctx, true);
                } else {
                  setS(() => wrong = true);
                  controller.clear();
                }
              },
              child: const Text('Увійти'),
            ),
          ],
        ),
      );
    },
  );

  return result ?? false;
}
