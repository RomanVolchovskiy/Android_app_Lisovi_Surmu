import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:hunting_signals/services/media_cache_service.dart';
import 'package:hunting_signals/services/study_plan_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/screens/drive_file_viewer_screen.dart';
import 'package:hunting_signals/screens/video_player_screen.dart';

class EducationTopicScreen extends StatefulWidget {
  final EducationTopic topic;
  /// Якщо передано — використовується замість EducationService.getMaterialsByTopic
  final Future<List<LearningMaterial>> Function(String topicId)? materialLoader;
  /// Показувати кнопку "Виконано" на кожному матеріалі (тільки з "План навчання")
  final bool showCompletion;

  const EducationTopicScreen({
    super.key,
    required this.topic,
    this.materialLoader,
    this.showCompletion = false,
  });

  @override
  State<EducationTopicScreen> createState() => _EducationTopicScreenState();
}

class _EducationTopicScreenState extends State<EducationTopicScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LearningMaterial> _materials = [];
  Set<String> _completedMaterials = {};
  bool _loading = true;

  static const _typeOrder = [
    LearningMaterialType.text,
    LearningMaterialType.video,
    LearningMaterialType.audio,
    LearningMaterialType.presentation,
    LearningMaterialType.infographic,
    LearningMaterialType.image,
  ];

  static const _typeIcons = {
    LearningMaterialType.text:         Icons.article_rounded,
    LearningMaterialType.video:        Icons.videocam_rounded,
    LearningMaterialType.audio:        Icons.headphones_rounded,
    LearningMaterialType.presentation: Icons.slideshow_rounded,
    LearningMaterialType.infographic:  Icons.bar_chart_rounded,
    LearningMaterialType.image:        Icons.image_rounded,
  };

  static const _typeColors = {
    LearningMaterialType.text:         Color(0xFF2F4F2F),
    LearningMaterialType.video:        Color(0xFF1565C0),
    LearningMaterialType.audio:        Color(0xFFC62828),
    LearningMaterialType.presentation: Color(0xFFBF360C),
    LearningMaterialType.infographic:  Color(0xFF6A1B9A),
    LearningMaterialType.image:        Color(0xFF2E7D32),
  };

  IconData _iconFor(LearningMaterial m) =>
      _typeIcons[m.type] ?? Icons.insert_drive_file_rounded;

  Color _colorFor(LearningMaterial m) =>
      _typeColors[m.type] ?? const Color(0xFF2F4F2F);

  String _subtitleFor(LearningMaterial m) => m.type.label;

  /// true якщо матеріал є відео
  bool _isVideo(LearningMaterial m) => m.type == LearningMaterialType.video;

  /// Плейсхолдер для відео без обкладинки
  Widget _videoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0F00), Color(0xFF2C1A0A)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_rounded, color: Colors.white.withValues(alpha: 0.4), size: 48),
          const SizedBox(height: 8),
          Text('Відео', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
        ],
      ),
    );
  }

  /// URL реального зображення-обкладинки (якщо є — YouTube або явно задано)
  String? _thumbnailImageUrl(LearningMaterial m) {
    if (!_isVideo(m)) return null;
    if (m.thumbnailUrl != null && m.thumbnailUrl!.isNotEmpty) {
      // Конвертуємо Google Drive посилання у пряме URL для відображення
      return MediaCacheService.toImageUrl(m.thumbnailUrl!);
    }
    final ytId = MediaCacheService.extractYouTubeId(m.driveUrl);
    if (ytId != null) return 'https://img.youtube.com/vi/$ytId/hqdefault.jpg';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _typeOrder.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final materials = widget.materialLoader != null
        ? await widget.materialLoader!(widget.topic.id)
        : await EducationService.getMaterialsByTopic(widget.topic.id);
    final completed = widget.showCompletion
        ? await StudyPlanService.getCompletedMaterials()
        : <String>{};
    if (mounted) setState(() {
      _materials = materials;
      _completedMaterials = completed;
      _loading = false;
    });
  }

  Future<void> _toggleDone(LearningMaterial m) async {
    await StudyPlanService.toggleMaterialDone(m.id);
    final completed = await StudyPlanService.getCompletedMaterials();
    if (mounted) setState(() => _completedMaterials = completed);
  }

  List<LearningMaterial> _byType(LearningMaterialType type) =>
      _materials.where((m) => m.type == type).toList();

  void _open(LearningMaterial m) {
    if (m.driveUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Посилання не вказано')),
      );
      return;
    }
    if (_isVideo(m)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(videoUrl: m.driveUrl, title: m.name),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriveFileViewerScreen(url: m.driveUrl, title: m.name),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: Text(widget.topic.name),
        backgroundColor: const Color(0xFF1C3A1C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4A017),
          labelColor: const Color(0xFFD4A017),
          unselectedLabelColor: Colors.white54,
          tabs: _typeOrder.map((t) => Tab(
            icon: Icon(_typeIcons[t], size: 18),
            text: t.label,
          )).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _typeOrder.map((type) {
                final items = _byType(type);
                final icon  = _typeIcons[type]!;

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Матеріали ще не додані',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final m = items[i];
                    final mIcon  = _iconFor(m);
                    final mColor = _colorFor(m);
                    final mLabel = _subtitleFor(m);
                    final isVid = _isVideo(m);
                    final thumbUrl = _thumbnailImageUrl(m);
                    return GestureDetector(
                      onTap: () => _open(m),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Піктограма — для відео: мініатюра з рамкою; для решти: іконка
                                      if (isVid)
                                        _VideoPictogram(thumbUrl: thumbUrl)
                                      else
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: mColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(mIcon, color: mColor, size: 24),
                                        ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              mLabel,
                                              style: TextStyle(fontSize: 11, color: mColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Кнопка "Відкрити"
                                      Expanded(
                                        child: Material(
                                          color: HuntingTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(10),
                                          child: InkWell(
                                            onTap: () => _open(m),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 9),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(mIcon, color: Colors.white, size: 16),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Відкрити',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Кнопка "Виконано" — тільки з "План навчання"
                                      if (widget.showCompletion)
                                        _DoneToggle(
                                          isDone: _completedMaterials.contains(m.id),
                                          onToggle: () => _toggleDone(m),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
    );
  }
}

// ── Мала піктограма відео з мисливською рамкою ───────────────────────────────
class _VideoPictogram extends StatelessWidget {
  final String? thumbUrl;
  const _VideoPictogram({this.thumbUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        // Зовнішня рамка — темно-золота, мисливська
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B6914), Color(0xFFD4A017), Color(0xFF8B6914)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFFFF0A0), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Мініатюра або плейсхолдер
              if (thumbUrl != null)
                CachedNetworkImage(
                  imageUrl: thumbUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              else
                _placeholder(),
              // Маленька кнопка Play
              Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
              // Мисливський значок у кутку
              Positioned(
                bottom: 2, right: 2,
                child: Icon(Icons.forest_rounded,
                    size: 10, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A2A0A), Color(0xFF2C4A1A)],
      ),
    ),
    child: Icon(Icons.videocam_rounded,
        color: Colors.white.withValues(alpha: 0.5), size: 22),
  );
}

// ── Кнопка "Виконано" ─────────────────────────────────────────────────────────
class _DoneToggle extends StatelessWidget {
  final bool isDone;
  final VoidCallback onToggle;
  const _DoneToggle({required this.isDone, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDone ? const Color(0xFF2E7D32) : Colors.grey[200],
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isDone ? Colors.white : Colors.grey[500],
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Виконано',
                style: TextStyle(
                  color: isDone ? Colors.white : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
