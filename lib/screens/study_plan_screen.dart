import 'package:flutter/material.dart';
import 'package:hunting_signals/models/education_models.dart';
import 'package:hunting_signals/services/education_service.dart';
import 'package:hunting_signals/services/practical_service.dart';
import 'package:hunting_signals/services/study_plan_service.dart';
import 'package:hunting_signals/screens/education_topic_screen.dart';
import 'package:hunting_signals/screens/level_thematic_screen.dart';

// ── Описи рівнів ──────────────────────────────────────────────────────────────
const _kLevels = [
  (key: 'basic',        label: 'Базовий рівень',       desc: 'Основи та фундаментальні знання',      color: Color(0xFF2E7D32), icon: Icons.signal_cellular_alt_1_bar_rounded),
  (key: 'standard',     label: 'Стандартний рівень',   desc: 'Загальний курс підготовки',             color: Color(0xFF1565C0), icon: Icons.signal_cellular_alt_2_bar_rounded),
  (key: 'professional', label: 'Професійний рівень',   desc: 'Поглиблене вивчення дисципліни',        color: Color(0xFFF57F17), icon: Icons.signal_cellular_alt_rounded),
  (key: 'expert',       label: 'Експертний рівень',    desc: 'Повна програма для фахівців',           color: Color(0xFFC62828), icon: Icons.military_tech_rounded),
];

class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  List<EducationTopic> _allEduTopics  = [];
  List<EducationTopic> _allPractTopics = [];
  List<UserPlan>       _userPlans     = [];
  Map<String, bool>    _completed     = {};

  // Рівень, обраний у секції "Обери навчальний план"
  String? _selectedLevel;
  List<StudyPlanEntry> _levelPlan        = [];
  bool                 _loadingLevelPlan = false;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      EducationService.getTopics(),
      PracticalService.getTopics(),
      StudyPlanService.getUserPlans(),
    ]);
    final eduTopics   = results[0] as List<EducationTopic>;
    final practTopics = results[1] as List<EducationTopic>;
    final userPlans   = results[2] as List<UserPlan>;

    // Рахуємо completion для всіх тем у всіх планах
    final completedM = await StudyPlanService.getCompletedMaterials();
    final allEduIds  = userPlans.expand((p) => p.theoreticalTopicIds).toSet().toList();
    final allPractIds = userPlans.expand((p) => p.practicalTopicIds).toSet().toList();
    final [eduComp, practComp] = await Future.wait([
      StudyPlanService.computeCompletionMap(allEduIds, completedM),
      StudyPlanService.computeCompletionMapGeneric(allPractIds, PracticalService.getMaterialsByTopic, completedM),
    ]);

    if (mounted) {
      setState(() {
        _allEduTopics   = eduTopics;
        _allPractTopics = practTopics;
        _userPlans      = userPlans;
        _completed      = {...eduComp, ...practComp};
        _loading        = false;
      });
    }

    if (_selectedLevel != null) await _loadLevelPlan(_selectedLevel!);
  }

  Future<void> _loadLevelPlan(String level) async {
    setState(() => _loadingLevelPlan = true);
    final plan      = await StudyPlanService.getAdminPlanByLevel(level);
    final completed = await StudyPlanService.getCompletedMaterials();

    final theorIds = plan.where((e) => e.topicType != 'practical').map((e) => e.topicId).toList();
    final practIds = plan.where((e) => e.topicType == 'practical').map((e) => e.topicId).toList();

    final results = await Future.wait([
      StudyPlanService.computeCompletionMap(theorIds, completed),
      StudyPlanService.computeCompletionMapGeneric(practIds, PracticalService.getMaterialsByTopic, completed),
    ]);

    if (mounted) {
      setState(() {
        _levelPlan        = plan;
        _completed        = {..._completed, ...results[0], ...results[1]};
        _loadingLevelPlan = false;
      });
    }
  }

  void _selectLevel(String level) {
    if (_selectedLevel == level) {
      setState(() { _selectedLevel = null; _levelPlan = []; });
      return;
    }
    setState(() => _selectedLevel = level);
    _loadLevelPlan(level);
  }

  EducationTopic? _eduTopicById(String id) {
    try { return _allEduTopics.firstWhere((t) => t.id == id); } catch (_) { return null; }
  }

  EducationTopic? _practTopicById(String id) {
    try { return _allPractTopics.firstWhere((t) => t.id == id); } catch (_) { return null; }
  }

  // для адміністративного плану по рівнях — враховує тип
  EducationTopic? _topicById(String id, [String type = 'theoretical']) =>
      type == 'practical' ? _practTopicById(id) : _eduTopicById(id);

  void _openTopic(EducationTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EducationTopicScreen(topic: topic, showCompletion: true)),
    ).then((_) => _load());
  }

  void _openPracticalTopic(EducationTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EducationTopicScreen(
                topic: topic,
                materialLoader: PracticalService.getMaterialsByTopic,
                showCompletion: true,
              )),
    ).then((_) => _load());
  }

  Future<void> _createUserPlan() async {
    final result = await Navigator.push<UserPlan>(
      context,
      MaterialPageRoute(
        builder: (_) => _UserPlanWizard(
          eduTopics:  _allEduTopics,
          practTopics: _allPractTopics,
          nextOrder:  _userPlans.length,
        ),
      ),
    );
    if (result != null) {
      await StudyPlanService.addUserPlan(result);
      await _load();
    }
  }

  Future<void> _deleteUserPlan(UserPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Видалити план?'),
        content: Text('Видалити план "${plan.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Видалити', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StudyPlanService.deleteUserPlan(plan.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Секція 1: Обери навчальний план ───────────────────────────
          _SectionHeader(
            icon: Icons.school_rounded,
            title: 'Обери навчальний план',
            subtitle: 'Оберіть рівень підготовки',
            color: const Color(0xFF1C3A1C),
          ),
          const SizedBox(height: 10),
          ..._kLevels.map((lvl) => _LevelCard(
                lvl: lvl,
                isSelected: _selectedLevel == lvl.key,
                onTap: () => _selectLevel(lvl.key),
              )),

          // Розгорнутий план обраного рівня
          if (_selectedLevel != null) ...[
            const SizedBox(height: 8),
            if (_loadingLevelPlan)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_levelPlan.isEmpty)
              _EmptyHint(
                icon: Icons.list_alt_rounded,
                text: 'Адміністратор ще не склав план для цього рівня',
              )
            else ...[
              _PlanTable(
                entries: _levelPlan,
                topicById: _topicById,
                completed: _completed,
                onOpen: (topic, type) => type == 'practical'
                    ? _openPracticalTopic(topic)
                    : _openTopic(topic),
                canDelete: false,
                onDelete: null,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LevelThematicScreen(level: _selectedLevel!),
                    ),
                  ),
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text('Тематичний план'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1C3A1C),
                    side: const BorderSide(color: Color(0xFF1C3A1C), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),

          // ── Секція 2: Створи індивідуальний план ──────────────────────
          Row(
            children: [
              Expanded(
                child: _SectionHeader(
                  icon: Icons.person_rounded,
                  title: 'Створи індивідуальний план',
                  subtitle: 'Персональний план навчання',
                  color: const Color(0xFF1565C0),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createUserPlan,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Створити план'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_userPlans.isEmpty)
            _EmptyHint(
              icon: Icons.playlist_add_rounded,
              text: 'Натисніть "Створити план" щоб скласти свій план навчання',
            )
          else
            ..._userPlans.map((plan) => _UserPlanCard(
                  plan: plan,
                  eduTopicById:  _eduTopicById,
                  practTopicById: _practTopicById,
                  completed: _completed,
                  onOpenEdu:   _openTopic,
                  onOpenPract: _openPracticalTopic,
                  onDelete: () => _deleteUserPlan(plan),
                )),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Картка рівня ─────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  final ({String key, String label, String desc, Color color, IconData icon}) lvl;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelCard({required this.lvl, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? lvl.color : lvl.color.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1.5,
          ),
          color: isSelected
              ? lvl.color.withValues(alpha: 0.08)
              : const Color(0xFFFFF8E7),
          boxShadow: isSelected
              ? [BoxShadow(color: lvl.color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lvl.color.withValues(alpha: 0.12),
                  border: Border.all(color: lvl.color.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Icon(lvl.icon, color: lvl.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lvl.label,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: lvl.color)),
                    Text(lvl.desc,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: lvl.color,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Заголовок секції ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }
}

// ── Таблиця плану ─────────────────────────────────────────────────────────────
class _PlanTable extends StatelessWidget {
  final List<StudyPlanEntry> entries;
  final EducationTopic? Function(String id, [String type]) topicById;
  final Map<String, bool> completed;
  final void Function(EducationTopic topic, String type) onOpen;
  final bool canDelete;
  final Future<void> Function(StudyPlanEntry)? onDelete;

  const _PlanTable({
    required this.entries,
    required this.topicById,
    required this.completed,
    required this.onOpen,
    required this.canDelete,
    required this.onDelete,
  });

  static const _typeIcon = {
    'theoretical': Icons.menu_book_rounded,
    'practical':   Icons.construction_rounded,
    'selfStudy':   Icons.self_improvement_rounded,
  };
  static const _typeColor = {
    'theoretical': Color(0xFF1C3A1C),
    'practical':   Color(0xFFBF360C),
    'selfStudy':   Color(0xFF6A1B9A),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4A017), width: 1.5),
        color: const Color(0xFFFFF8E7),
      ),
      child: Column(
        children: [
          _TableHeaderRow(canDelete: canDelete),
          const Divider(height: 1, color: Color(0xFFD4A017)),
          ...entries.asMap().entries.map((entry) {
            final i     = entry.key;
            final item  = entry.value;
            final topic = topicById(item.topicId, item.topicType);
            final done  = completed[item.topicId] ?? false;
            final icon  = _typeIcon[item.topicType] ?? Icons.menu_book_rounded;
            final color = _typeColor[item.topicType] ?? const Color(0xFF1C3A1C);
            return Column(
              children: [
                _PlanTableRow(
                  number:    i + 1,
                  topic:     topic,
                  topicId:   item.topicId,
                  topicType: item.topicType,
                  typeIcon:  icon,
                  typeColor: color,
                  isDone:    done,
                  canDelete: canDelete,
                  onOpen:    topic != null ? () => onOpen(topic, item.topicType) : null,
                  onDelete:  canDelete && onDelete != null ? () => onDelete!(item) : null,
                ),
                if (i < entries.length - 1)
                  const Divider(height: 1, indent: 8, endIndent: 8, color: Color(0xFFE8C87A)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  final bool canDelete;
  const _TableHeaderRow({required this.canDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C3A1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 32,
            child: Text('№', textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD4A017), fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Назва теми',
                style: TextStyle(color: Color(0xFFD4A017), fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(
            width: 60,
            child: Text('Виконано', textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD4A017), fontWeight: FontWeight.w700, fontSize: 11)),
          ),
          if (canDelete) const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _PlanTableRow extends StatelessWidget {
  final int number;
  final EducationTopic? topic;
  final String topicId;
  final String topicType;
  final IconData typeIcon;
  final Color typeColor;
  final bool isDone;
  final bool canDelete;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  const _PlanTableRow({
    required this.number, required this.topic, required this.topicId,
    required this.topicType, required this.typeIcon, required this.typeColor,
    required this.isDone, required this.canDelete,
    required this.onOpen, required this.onDelete,
  });

  static String _typeLabel(String type) {
    switch (type) {
      case 'practical': return 'Практична';
      case 'selfStudy': return 'Самостійна';
      default:          return 'Теоретична';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1C3A1C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$number', textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1C3A1C))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic?.name ?? topicId,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: onOpen != null ? const Color(0xFF1565C0) : Colors.grey,
                      decoration: onOpen != null ? TextDecoration.underline : TextDecoration.none,
                      decorationColor: const Color(0xFF1565C0),
                    ),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: typeColor.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 10, color: typeColor),
                            const SizedBox(width: 3),
                            Text(
                              _typeLabel(topicType),
                              style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22)
                  : const SizedBox.shrink(),
            ),
          ),
          if (canDelete)
            SizedBox(
              width: 32,
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[50],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }
}

class _TopicPickerDialog extends StatelessWidget {
  final List<EducationTopic> topics;
  const _TopicPickerDialog({required this.topics});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Оберіть тему'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: topics.length,
          itemBuilder: (_, i) {
            final t = topics[i];
            return ListTile(
              leading: const Icon(Icons.topic_rounded, color: Color(0xFF1C3A1C)),
              title: Text(t.name, style: const TextStyle(fontSize: 14)),
              subtitle: t.description.isNotEmpty
                  ? Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11))
                  : null,
              onTap: () => Navigator.pop(context, t),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
      ],
    );
  }
}

// ── Картка індивідуального плану ─────────────────────────────────────────────
class _UserPlanCard extends StatefulWidget {
  final UserPlan plan;
  final EducationTopic? Function(String) eduTopicById;
  final EducationTopic? Function(String) practTopicById;
  final Map<String, bool> completed;
  final void Function(EducationTopic) onOpenEdu;
  final void Function(EducationTopic) onOpenPract;
  final VoidCallback onDelete;

  const _UserPlanCard({
    required this.plan,
    required this.eduTopicById,
    required this.practTopicById,
    required this.completed,
    required this.onOpenEdu,
    required this.onOpenPract,
    required this.onDelete,
  });

  @override
  State<_UserPlanCard> createState() => _UserPlanCardState();
}

class _UserPlanCardState extends State<_UserPlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final totalTopics = plan.theoreticalTopicIds.length + plan.practicalTopicIds.length;
    final doneTopics = [
      ...plan.theoreticalTopicIds,
      ...plan.practicalTopicIds,
    ].where((id) => widget.completed[id] == true).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.5), width: 1.5),
        color: const Color(0xFFF0F4FF),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Заголовок картки
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Прогрес
                  if (totalTopics > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$doneTopics/$totalTopics',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Видалити план',
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Вміст (якщо розгорнуто)
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Теоретичні теми
                  if (plan.theoreticalTopicIds.isNotEmpty) ...[
                    _SubSectionLabel(
                      icon: Icons.menu_book_rounded,
                      label: 'Теоретичні матеріали',
                      color: const Color(0xFF1C3A1C),
                    ),
                    const SizedBox(height: 6),
                    ...plan.theoreticalTopicIds.asMap().entries.map((e) {
                      final topic = widget.eduTopicById(e.value);
                      final done  = widget.completed[e.value] ?? false;
                      return _PlanTopicRow(
                        number: e.key + 1,
                        topic: topic,
                        topicId: e.value,
                        isDone: done,
                        onOpen: topic != null ? () => widget.onOpenEdu(topic) : null,
                      );
                    }),
                    const SizedBox(height: 10),
                  ],

                  // Практичні теми
                  if (plan.practicalTopicIds.isNotEmpty) ...[
                    _SubSectionLabel(
                      icon: Icons.construction_rounded,
                      label: 'Практичні матеріали',
                      color: const Color(0xFFBF360C),
                    ),
                    const SizedBox(height: 6),
                    ...plan.practicalTopicIds.asMap().entries.map((e) {
                      final topic = widget.practTopicById(e.value);
                      final done  = widget.completed[e.value] ?? false;
                      return _PlanTopicRow(
                        number: e.key + 1,
                        topic: topic,
                        topicId: e.value,
                        isDone: done,
                        onOpen: topic != null ? () => widget.onOpenPract(topic) : null,
                      );
                    }),
                  ],

                  if (plan.theoreticalTopicIds.isEmpty && plan.practicalTopicIds.isEmpty)
                    const Text(
                      'Теми не обрані',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SubSectionLabel({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _PlanTopicRow extends StatelessWidget {
  final int number;
  final EducationTopic? topic;
  final String topicId;
  final bool isDone;
  final VoidCallback? onOpen;

  const _PlanTopicRow({
    required this.number,
    required this.topic,
    required this.topicId,
    required this.isDone,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$number.',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Text(
                topic?.name ?? topicId,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: onOpen != null ? const Color(0xFF1565C0) : Colors.grey,
                  decoration: onOpen != null ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: const Color(0xFF1565C0),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: isDone
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Майстер створення індивідуального плану ───────────────────────────────────
class _UserPlanWizard extends StatefulWidget {
  final List<EducationTopic> eduTopics;
  final List<EducationTopic> practTopics;
  final int nextOrder;

  const _UserPlanWizard({
    required this.eduTopics,
    required this.practTopics,
    required this.nextOrder,
  });

  @override
  State<_UserPlanWizard> createState() => _UserPlanWizardState();
}

class _UserPlanWizardState extends State<_UserPlanWizard> {
  int _step = 0; // 0=назва, 1=теоретичні, 2=практичні

  final _nameCtrl = TextEditingController();
  final Set<String> _selectedEdu   = {};
  final Set<String> _selectedPract = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введіть назву плану')),
        );
        return;
      }
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _finish() {
    final plan = UserPlan(
      id: 'up_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      theoreticalTopicIds: _selectedEdu.toList(),
      practicalTopicIds:   _selectedPract.toList(),
      order: widget.nextOrder,
    );
    Navigator.pop(context, plan);
  }

  @override
  Widget build(BuildContext context) {
    const stepTitles = ['Назва плану', 'Теоретичні теми', 'Практичні теми'];
    final isLast = _step == 2;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E6),
      appBar: AppBar(
        title: const Text('Створити план'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Індикатор кроків
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: List.generate(3, (i) {
                final active = i == _step;
                final done   = i < _step;
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: done || active
                                ? const Color(0xFF1565C0)
                                : Colors.grey[300],
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 4),
                    ],
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: List.generate(3, (i) {
                final active = i == _step;
                final done   = i < _step;
                return Expanded(
                  child: Text(
                    stepTitles[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: done || active ? const Color(0xFF1565C0) : Colors.grey,
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Вміст кроку
          Expanded(
            child: _step == 0
                ? _NameStep(controller: _nameCtrl)
                : _step == 1
                    ? _TopicMultiSelect(
                        topics:   widget.eduTopics,
                        selected: _selectedEdu,
                        icon:     Icons.menu_book_rounded,
                        color:    const Color(0xFF1C3A1C),
                        emptyText: 'Немає теоретичних тем',
                      )
                    : _TopicMultiSelect(
                        topics:   widget.practTopics,
                        selected: _selectedPract,
                        icon:     Icons.construction_rounded,
                        color:    const Color(0xFFBF360C),
                        emptyText: 'Немає практичних тем',
                      ),
          ),

          // Навігаційні кнопки
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton.icon(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Назад'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _next,
                    icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 16),
                    label: Text(isLast ? 'Зберегти план' : 'Далі'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  const _NameStep({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Введіть назву вашого плану навчання',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1C3A1C)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Наприклад: "Підготовка до іспиту" або "Весняний курс"',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Назва плану',
              prefixIcon: const Icon(Icons.edit_rounded, color: Color(0xFF1565C0)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1565C0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicMultiSelect extends StatefulWidget {
  final List<EducationTopic> topics;
  final Set<String> selected;
  final IconData icon;
  final Color color;
  final String emptyText;

  const _TopicMultiSelect({
    required this.topics,
    required this.selected,
    required this.icon,
    required this.color,
    required this.emptyText,
  });

  @override
  State<_TopicMultiSelect> createState() => _TopicMultiSelectState();
}

class _TopicMultiSelectState extends State<_TopicMultiSelect> {
  void _toggle(String id) {
    setState(() {
      if (widget.selected.contains(id)) {
        widget.selected.remove(id);
      } else {
        widget.selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(widget.emptyText, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.color, size: 16),
              const SizedBox(width: 6),
              Text(
                'Оберіть теми (${widget.selected.length} обрано)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: widget.topics.length,
            itemBuilder: (_, i) {
              final t = widget.topics[i];
              final checked = widget.selected.contains(t.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: checked ? 2 : 1,
                child: InkWell(
                  onTap: () => _toggle(t.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: checked
                          ? widget.color.withValues(alpha: 0.08)
                          : Colors.white,
                      border: Border.all(
                        color: checked ? widget.color : Colors.grey[300]!,
                        width: checked ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: checked ? widget.color : Colors.transparent,
                            border: Border.all(
                              color: checked ? widget.color : Colors.grey[400]!,
                              width: 2,
                            ),
                          ),
                          child: checked
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: checked ? widget.color : Colors.black87,
                                ),
                              ),
                              if (t.description.isNotEmpty)
                                Text(
                                  t.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
          ),
        ),
      ],
    );
  }
}
