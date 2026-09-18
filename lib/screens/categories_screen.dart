import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/widgets/signal_card.dart';
import 'package:hunting_signals/widgets/platform_dialog.dart';
import 'package:hunting_signals/utils/platform_utils.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  List<SignalCategory> _categories = [];
  List<HuntingSignal> _allSignals = [];
  List<HuntingSignal> _filteredSignals = [];
  String _selectedCategory = 'Всі категорії';
  bool _isLoading = true;
  bool _showLeftArrow = false;
  bool _showRightArrow = true;
  late AnimationController _arrowAnim;
  late Animation<double> _arrowOffset;
  final ScrollController _chipScroll = ScrollController();
  StreamSubscription<List<HuntingSignal>>? _signalsSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Підписка на real-time оновлення з Firebase
    _signalsSub = HuntingDataService.signalsStream().listen((signals) {
      if (!mounted) return;
      setState(() {
        _allSignals = signals;
        _filteredSignals = _selectedCategory == 'Всі категорії'
            ? signals
            : signals.where((s) => s.category == _selectedCategory).toList();
        _isLoading = false;
      });
    });
    _arrowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _arrowOffset = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _arrowAnim, curve: Curves.easeInOut),
    );
    _chipScroll.addListener(_onChipScroll);
  }

  void _onChipScroll() {
    final atStart = _chipScroll.offset <= 0;
    final atEnd = _chipScroll.offset >= _chipScroll.position.maxScrollExtent;
    final newLeft = !atStart;
    final newRight = !atEnd;
    if (newLeft != _showLeftArrow || newRight != _showRightArrow) {
      setState(() {
        _showLeftArrow = newLeft;
        _showRightArrow = newRight;
      });
    }
  }

  @override
  void dispose() {
    _signalsSub?.cancel();
    _arrowAnim.dispose();
    _chipScroll.dispose();
    super.dispose();
  }

  void _scrollChipsForward() {
    final target = (_chipScroll.offset + 140).clamp(
      0.0,
      _chipScroll.position.maxScrollExtent,
    );
    _chipScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollChipsBack() {
    final target = (_chipScroll.offset - 140).clamp(
      0.0,
      _chipScroll.position.maxScrollExtent,
    );
    _chipScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadData() async {
    try {
      final categories = await HuntingDataService.getCategories();
      final signals = await HuntingDataService.getAllSignals();

      setState(() {
        _categories = categories;
        _allSignals = signals;
        _filteredSignals = signals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showPlatformSnackBar(context, 'Помилка завантаження: $e');
      }
    }
  }

  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'Всі категорії') {
        _filteredSignals = _allSignals;
      } else {
        _filteredSignals = _allSignals
            .where((signal) => signal.category == category)
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: isIOS
            ? const CupertinoActivityIndicator(radius: 16)
            : const CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        // Category Filter Chips
        SizedBox(
          height: 60,
          child: Stack(
            children: [
              ListView.builder(
                controller: _chipScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 12, right: 52),
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  final categoryName = index == 0
                      ? 'Всі категорії'
                      : _categories[index - 1].name;
                  final isSelected = _selectedCategory == categoryName;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 120),
                      child: ChoiceChip(
                        label: Center(child: Text(categoryName)),
                        selected: isSelected,
                        onSelected: (selected) => _filterByCategory(categoryName),
                        selectedColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Theme.of(context).primaryColorDark
                              : Colors.grey[700],
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Ліва стрілка — з'являється коли прогорнуто вправо
              if (_showLeftArrow)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 64,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0x00FAF0E6), Color(0xFFFAF0E6)],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedBuilder(
                        animation: _arrowOffset,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(-_arrowOffset.value, 0),
                          child: GestureDetector(
                            onTap: _scrollChipsBack,
                            child: Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4A017),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4A017).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chevron_left_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Права стрілка — зникає коли досягнуто кінця
              if (_showRightArrow)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 64,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0x00FAF0E6), Color(0xFFFAF0E6)],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedBuilder(
                        animation: _arrowOffset,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(_arrowOffset.value, 0),
                          child: GestureDetector(
                            onTap: _scrollChipsForward,
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4A017),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4A017).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Signals List
        Expanded(
          child: _filteredSignals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.surround_sound,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Сигнали не знайдені',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Виберіть іншу категорію',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredSignals.length,
                  itemBuilder: (context, index) {
                    final signal = _filteredSignals[index];
                    return SignalCard(signal: signal);
                  },
                ),
        ),
      ],
    );
  }
}
