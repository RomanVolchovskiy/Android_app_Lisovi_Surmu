import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunting_signals/models/hunting_event.dart';
import 'package:hunting_signals/services/firebase_service.dart';

class EventsService {
  static const String _userEventsKey = 'user_events';

  // ── USER EVENTS (локальні, з кодом обміну) ────────────────────────

  static Future<List<HuntingEvent>> getUserEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userEventsKey);
    if (jsonStr == null) return [];
    final List<dynamic> list = jsonDecode(jsonStr);
    return list
        .map((e) => HuntingEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a personal event, saves locally and uploads to Firebase for sharing.
  /// Returns the created event (with shareCode).
  static Future<HuntingEvent> createUserEvent({
    required String title,
    required String description,
    required String location,
    required DateTime date,
    required String type,
    List<String> mainSignalIds = const [],
    List<String> accompanyingSignalIds = const [],
  }) async {
    final event = HuntingEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      location: location,
      date: date,
      type: type,
      mainSignalIds: mainSignalIds,
      accompanyingSignalIds: accompanyingSignalIds,
      isGlobal: false,
      shareCode: _generateShareCode(),
    );
    final events = await getUserEvents();
    events.add(event);
    await _saveUserEvents(events);
    // Upload to Firebase so it can be found by share code
    FirebaseService.saveSharedEvent(event.toJson()); // fire-and-forget
    return event;
  }

  /// Removes a user event from the local list.
  static Future<void> deleteUserEvent(String id) async {
    final events = await getUserEvents();
    events.removeWhere((e) => e.id == id);
    await _saveUserEvents(events);
  }

  /// Finds an event by share code in Firebase and adds it to the local list.
  /// Returns null on success, or an error message.
  static Future<String?> importEventByCode(String code) async {
    final data = await FirebaseService.findSharedEventByCode(
      code.toUpperCase(),
    );
    if (data == null) return 'Подію з таким кодом не знайдено';
    final event = HuntingEvent.fromJson(data);
    if (event.id.isEmpty) return 'Невірні дані події';
    final events = await getUserEvents();
    if (events.any((e) => e.id == event.id)) return 'Цю подію вже додано';
    events.add(event);
    await _saveUserEvents(events);
    return null; // null = success
  }

  // ── GLOBAL EVENTS (Firebase, тільки адмін) ───────────────────────

  static Stream<List<HuntingEvent>> globalEventsStream() {
    return FirebaseService.globalEventsStream().map((list) {
      final events =
          list.map((e) => HuntingEvent.fromJson(e)).toList();
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    });
  }

  static Future<bool> createGlobalEvent(HuntingEvent event) =>
      FirebaseService.saveGlobalEvent(event.toJson());

  static Future<bool> updateGlobalEvent(HuntingEvent event) =>
      FirebaseService.saveGlobalEvent(event.toJson());

  static Future<bool> deleteGlobalEvent(String id) =>
      FirebaseService.deleteGlobalEvent(id);

  /// Fetches a shared event by code and promotes it to a global event
  /// (visible to all users). Returns null on success, error string on failure.
  static Future<String?> promoteToGlobal(String shareCode) async {
    final data = await FirebaseService.findSharedEventByCode(
      shareCode.toUpperCase(),
    );
    if (data == null) return 'Подію з таким кодом не знайдено';
    final Map<String, dynamic> globalData = Map.from(data)
      ..['isGlobal'] = true
      ..['shareCode'] = null;
    final success = await FirebaseService.saveGlobalEvent(globalData);
    return success ? null : 'Помилка збереження події';
  }

  // ── HELPERS ─────────────────────────────────────────────────────

  static Future<void> _saveUserEvents(List<HuntingEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userEventsKey,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  static String _generateShareCode() {
    // Unambiguous alphanumeric chars (no 0/O, 1/I/l)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
