import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/hunting_data_service.dart';
import 'package:hunting_signals/services/playlist_service.dart';
import 'package:hunting_signals/services/audio_service.dart';
import 'package:hunting_signals/theme/hunting_theme.dart';
import 'package:hunting_signals/widgets/signal_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<HuntingSignal> _favoriteSignals = [];
  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorite_signals') ?? [];
    final allSignals = await HuntingDataService.getAllSignals();
    final playlists = await PlaylistService.getPlaylists();

    if (mounted) {
      setState(() {
        _favoriteSignals = allSignals.where((s) => favoriteIds.contains(s.id)).toList();
        _playlists = playlists;
        _loading = false;
      });
    }
  }

  void _showCreatePlaylistDialog() {
    if (_favoriteSignals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Спочатку додайте сигнали до обраного')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final selectedIds = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Створити плейлист'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Назва плейлиста *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Оберіть сигнали:', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView(
                    shrinkWrap: true,
                    children: _favoriteSignals.map((signal) {
                      return CheckboxListTile(
                        dense: true,
                        title: Text(signal.name, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(signal.category, style: const TextStyle(fontSize: 12)),
                        value: selectedIds.contains(signal.id),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedIds.add(signal.id);
                            } else {
                              selectedIds.remove(signal.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введіть назву плейлиста')),
                  );
                  return;
                }
                await PlaylistService.addPlaylist(nameCtrl.text.trim(), selectedIds.toList());
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              child: const Text('Зберегти'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playPlaylist(Playlist playlist) async {
    final allSignals = await HuntingDataService.getAllSignals();
    final signals = playlist.signalIds
        .map((id) => allSignals.where((s) => s.id == id).firstOrNull)
        .whereType<HuntingSignal>()
        .where((s) => s.audioUrl != null && s.audioUrl!.isNotEmpty)
        .toList();

    if (signals.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('У плейлисті немає сигналів з аудіо')),
        );
      }
      return;
    }

    final audioService = AudioService();
    int currentIndex = 0;

    Future<void> playNext() async {
      if (currentIndex >= signals.length) return;
      await audioService.play(signals[currentIndex].audioUrl!);
      currentIndex++;
    }

    audioService.addListener(() {
      if (!audioService.isPlaying && currentIndex < signals.length) {
        playNext();
      }
    });

    await playNext();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Відтворення плейлиста: ${playlist.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red[700]!, Colors.red[900]!],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Обрані Сигнали',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Ваші улюблені мисливські сигнали',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: HuntingTheme.primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: HuntingTheme.primaryColor,
          tabs: const [
            Tab(text: 'Мої обрані'),
            Tab(text: 'Плейлисти'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFavoritesTab(),
                    _buildPlaylistsTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFavoritesTab() {
    if (_favoriteSignals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Ще немає обраних сигналів',
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Додавайте сигнали до обраного, натискаючи на іконку серця',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/categories'),
              icon: const Icon(Icons.surround_sound),
              label: const Text('Перейти до сигналів'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HuntingTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteSignals.length,
      itemBuilder: (ctx, i) => SignalCard(signal: _favoriteSignals[i]),
    );
  }

  Widget _buildPlaylistsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._playlists.map((playlist) => _buildPlaylistCard(playlist)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCreatePlaylistDialog,
            icon: const Icon(Icons.add),
            label: const Text('Створити плейлист'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        if (_playlists.isEmpty) ...[
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.queue_music, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Плейлисти відсутні',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green.withValues(alpha: 0.05)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.queue_music, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.audiotrack, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${playlist.signalIds.length} сигнал(ів)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Видалити плейлист?'),
                    content: Text('Видалити "${playlist.name}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ні')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Видалити', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await PlaylistService.deletePlaylist(playlist.id);
                  _loadData();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.green, size: 32),
              onPressed: () => _playPlaylist(playlist),
            ),
          ],
        ),
      ),
    );
  }
}
