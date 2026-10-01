import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../voice/provider/voice_player_provider.dart';

class VoiceMessagePlayer extends ConsumerWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMe;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMe,
  });

  static const int _barCount = 32;

  // Same bar pattern every time, seeded from the audio url
  List<double> _generateBarHeights() {
    final random = Random(audioUrl.hashCode);
    return List.generate(_barCount, (_) => 0.3 + random.nextDouble() * 0.7);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // 1.0 -> "1x", 1.5 -> "1.5x", 2.0 -> "2x"
  String _formatSpeed(double speed) {
    return speed == speed.roundToDouble()
        ? '${speed.toInt()}x'
        : '${speed}x';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (url: audioUrl, seconds: durationSeconds);

    // watch = rebuild when playing/position/speed changes
    final player = ref.watch(voicePlayerProvider(args));
    // read notifier = only used to call actions (play, seek, speed)
    final notifier = ref.read(voicePlayerProvider(args).notifier);

    final barHeights = _generateBarHeights();

    final accentColor = AppColors.primary;
    final playedBarColor = accentColor;
    final unplayedBarColor = accentColor.withOpacity(0.3);

    final totalMs = player.total.inMilliseconds > 0 ? player.total.inMilliseconds : 1;
    final progress = (player.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final activeBarIndex = (progress * _barCount).floor();

    final displayTime = player.isPlaying || player.position > Duration.zero
        ? _formatDuration(player.position)
        : _formatDuration(player.total);

    return SizedBox(
      width: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Play / Pause button
          GestureDetector(
            onTap: () {
              AppHaptics.tap();
              notifier.togglePlay();
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: accentColor,
              child: Icon(
                player.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Waveform bars + duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // LayoutBuilder gives us the real width of the waveform
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapUp: (details) {
                        // localPosition is already inside the waveform,
                        // so we only divide by the waveform width
                        final fraction =
                            details.localPosition.dx / constraints.maxWidth;
                        final barIndex = (fraction * _barCount)
                            .clamp(0, _barCount - 1)
                            .floor();
                        notifier.seekToBar(barIndex, _barCount);
                      },
                      child: SizedBox(
                        height: 28,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_barCount, (index) {
                            final isPlayed = index <= activeBarIndex;
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 0.8),
                                height: 24 * barHeights[index],
                                decoration: BoxDecoration(
                                  color: isPlayed ? playedBarColor : unplayedBarColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  displayTime,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Speed button: tap to change 1x -> 1.5x -> 2x
          GestureDetector(
            onTap: () {
              AppHaptics.tap();
              notifier.cycleSpeed();
            },
            child: Container(
              width: 38,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _formatSpeed(player.speed),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}