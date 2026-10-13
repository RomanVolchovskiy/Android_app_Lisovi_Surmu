import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/services/quiz_results_service.dart';

/// «Мої результати»: останні 50 пробних тестів (з додатку й сайту).
class MyQuizResultsScreen extends StatefulWidget {
  const MyQuizResultsScreen({super.key});

  @override
  State<MyQuizResultsScreen> createState() => _MyQuizResultsScreenState();
}

class _MyQuizResultsScreenState extends State<MyQuizResultsScreen> {
  late Future<List<QuizResult>> _future = QuizResultsService.myResults();

  static String _fmt(DateTime? d) {
    if (d == null) return '—';
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  static Color _color(int pct) =>
      pct >= 75 ? const Color(0xFF2E7D32) : pct >= 50 ? const Color(0xFFF57F17) : const Color(0xFFC62828);

  Widget _empty(IconData icon, String title, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: const Text('Мої результати'),
        backgroundColor: const Color(0xFF1C3A1C),
        foregroundColor: Colors.white,
      ),
      body: FirebaseAuth.instance.currentUser == null
          ? _empty(Icons.login_rounded, 'Потрібен вхід', 'Увійдіть в акаунт — результати пробних тестів зберігатимуться тут')
          : FutureBuilder<List<QuizResult>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _empty(Icons.error_outline_rounded, 'Не вдалося завантажити', '${snap.error}');
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) {
                  return _empty(Icons.history_rounded, 'Ще немає результатів', 'Пройдіть пробний тест — результат збережеться тут');
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _future = QuizResultsService.myResults());
                    await _future;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final c = _color(r.percent);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: c.withValues(alpha: 0.5)),
                        ),
                        child: ListTile(
                          leading: Icon(r.kind == 'audio' ? Icons.headphones_rounded : Icons.menu_book_rounded, color: c),
                          title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('${_fmt(r.createdAt)} · ${r.correct} з ${r.total}'),
                          trailing: Text('${r.percent}%', style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
