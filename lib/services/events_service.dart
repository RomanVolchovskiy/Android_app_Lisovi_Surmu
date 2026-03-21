import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunting_signals/models/hunting_event.dart';

class EventsService {
  static const String _key = 'hunting_events';

  static Future<List<HuntingEvent>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) {
      final defaults = _defaultEvents();
      await _saveEvents(defaults);
      return defaults;
    }
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => HuntingEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> addEvent(HuntingEvent event) async {
    final events = await getEvents();
    events.add(event);
    await _saveEvents(events);
  }

  static Future<void> deleteEvent(String id) async {
    final events = await getEvents();
    events.removeWhere((e) => e.id == id);
    await _saveEvents(events);
  }

  static Future<void> _saveEvents(List<HuntingEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  static List<HuntingEvent> _defaultEvents() => [
    HuntingEvent(
      id: 'evt_001',
      title: 'Відкриття сезону',
      description: 'Традиційне відкриття мисливського сезону з урочистою церемонією та виконанням класичних мисливських сигналів.',
      location: 'Ліс Соснівський',
      date: DateTime(2026, 10, 15),
      type: 'Полювання',
    ),
    HuntingEvent(
      id: 'evt_002',
      title: 'Свято мисливської музики',
      description: 'Фестиваль традиційної мисливської сигнальної музики за участю мисливських колективів з усієї країни.',
      location: 'Мисливський клуб "Сокіл"',
      date: DateTime(2026, 10, 28),
      type: 'Фестиваль',
      relatedSignalId: '1',
    ),
  ];
}
