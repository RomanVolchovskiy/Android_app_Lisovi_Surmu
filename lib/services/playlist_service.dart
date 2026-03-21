import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Playlist {
  final String id;
  final String name;
  final List<String> signalIds;

  Playlist({required this.id, required this.name, required this.signalIds});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'signalIds': signalIds,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    signalIds: List<String>.from(json['signalIds'] ?? []),
  );
}

class PlaylistService {
  static const String _key = 'playlists';

  static Future<List<Playlist>> getPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> addPlaylist(String name, List<String> signalIds) async {
    final playlists = await getPlaylists();
    playlists.add(Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      signalIds: signalIds,
    ));
    await _savePlaylists(playlists);
  }

  static Future<void> deletePlaylist(String id) async {
    final playlists = await getPlaylists();
    playlists.removeWhere((p) => p.id == id);
    await _savePlaylists(playlists);
  }

  static Future<void> _savePlaylists(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(playlists.map((p) => p.toJson()).toList()));
  }
}
