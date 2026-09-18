import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/practical_service.dart';
import 'package:hunting_signals/screens/education_topic_screen.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';

class PracticalTasksScreen extends StatefulWidget {
  const PracticalTasksScreen({super.key});

  @override
  State<PracticalTasksScreen> createState() => _PracticalTasksScreenState();
}

class _PracticalTasksScreenState extends State<PracticalTasksScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  List<EducationTopic> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final topics = await PracticalService.getTopics();
    if (mounted) setState(() { _topics = topics; _loading = false; });
  }

  void _open(EducationTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EducationTopicScreen(
          topic: topic,
          materialLoader: PracticalService.getMaterialsByTopic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Практичні завдання ще не додані',
                style: TextStyle(color: Colors.grey[600], fontSize: 15)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Оновити'),
              style: TextButton.styleFrom(foregroundColor: HuntingTheme.primaryColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _topics.length,
        itemBuilder: (context, i) {
          final topic = _topics[i];
          return GestureDetector(
            onTap: () => _open(topic),
            child: Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF8E7), Color(0xFFE8C87A)],
                  ),
                  border: Border.all(color: const Color(0xFFD4A017), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBF360C).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.assignment_rounded,
                                  color: Color(0xFFBF360C), size: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topic.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (topic.description.isNotEmpty)
                                  Text(topic.description,
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey[600]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Material(
                          color: HuntingTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => _open(topic),
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text('Переглянути',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
