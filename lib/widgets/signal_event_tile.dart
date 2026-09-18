import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hunting_signals/models/hunting_models.dart';
import 'package:hunting_signals/services/audio_service.dart';
import 'package:hunting_signals/screens/drive_file_viewer_screen.dart';

/// Signal tile for event details: numbered, play/pause/stop, notation viewer.
class SignalEventTile extends StatelessWidget {
  final HuntingSignal signal;
  final int number;
  final Color accentColor;

  const SignalEventTile({
    super.key,
    required this.signal,
    required this.number,
    required this.accentColor,
  });

  Future<void> _openNotation(BuildContext context) async {
    final url = signal.notationUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ноти не додані для цього сигналу')),
      );
      return;
    }
    // PDF → external browser
    if (url.toLowerCase().endsWith('.pdf')) {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    // Other (Google Drive image/doc) → WebView
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => DriveFileViewerScreen(
            url: url,
            title: 'Ноти: ${signal.name}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio =
        signal.audioUrl != null && signal.audioUrl!.isNotEmpty;
    final hasNotation =
        signal.notationUrl != null && signal.notationUrl!.isNotEmpty;

    return ListenableBuilder(
      listenable: AudioService(),
      builder: (context, _) {
        final audio = AudioService();
        final isThisPlaying =
            audio.isPlaying && audio.currentSignalId == signal.audioUrl;
        final isThisLoaded =
            audio.currentSignalId == signal.audioUrl;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: accentColor.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            child: Row(
              children: [
                // Number badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Signal info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signal.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        signal.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Notation button
                if (hasNotation)
                  IconButton(
                    icon: Icon(
                      Icons.music_note,
                      color: accentColor.withValues(alpha: 0.8),
                      size: 20,
                    ),
                    tooltip: 'Переглянути ноти',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _openNotation(context),
                  ),

                // Play / Pause button
                if (hasAudio)
                  IconButton(
                    icon: Icon(
                      isThisPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: accentColor,
                      size: 30,
                    ),
                    tooltip: isThisPlaying ? 'Пауза' : 'Відтворити',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: () async {
                      if (isThisPlaying) {
                        await audio.pause();
                      } else {
                        try {
                          await audio.play(signal.audioUrl!);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Помилка відтворення: $e'),
                              ),
                            );
                          }
                        }
                      }
                    },
                  )
                else
                  Icon(
                    Icons.volume_off,
                    color: Colors.grey[400],
                    size: 20,
                  ),

                // Stop button — only when this signal is loaded
                if (isThisLoaded) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.red.shade400,
                      size: 24,
                    ),
                    tooltip: 'Зупинити',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: () => audio.stop(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Section header with colored left bar used in event details.
class SignalSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const SignalSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
