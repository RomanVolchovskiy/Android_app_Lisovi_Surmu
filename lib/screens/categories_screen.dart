import 'package:flutter/cupertino.dart';
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

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<SignalCategory> _categories = [];
  List<HuntingSignal> _allSignals = [];
  List<HuntingSignal> _filteredSignals = [];
  String _selectedCategory = 'Всі категорії';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length + 1,
            itemBuilder: (context, index) {
              final categoryName = index == 0
                  ? 'Всі категорії'
                  : _categories[index - 1].name;
              final isSelected = _selectedCategory == categoryName;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(categoryName),
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
              );
            },
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
