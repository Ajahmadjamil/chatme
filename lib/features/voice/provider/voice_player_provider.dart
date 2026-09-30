import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

// One voice message is identified by its url + saved duration
typedef VoiceArgs = ({String url, int seconds});

class VoicePlayerState {
  final bool isPlaying;
  final Duration position;
  final Duration total;
  final double speed; // 1.0, 1.5 or 2.0

  const VoicePlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.total = Duration.zero,
    this.speed = 1.0,
  });

  VoicePlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? total,
    double? speed,
  }) {
    return VoicePlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      total: total ?? this.total,
      speed: speed ?? this.speed,
    );
  }
}

// Riverpod 3: the family argument comes through the constructor
class VoicePlayerNotifier extends Notifier<VoicePlayerState> {
  VoicePlayerNotifier(this.arg);

  final VoiceArgs arg;

  // The speeds we cycle through when the user taps the speed button
  static const List<double> _speeds = [1.0, 1.5, 2.0];

  late AudioPlayer _player;
  bool _isLoaded = false;

  @override
  VoicePlayerState build() {
    _isLoaded = false;
    _player = AudioPlayer();

    // Play / pause changes
    final stateSub = _player.playerStateStream.listen((playerState) {
      state = state.copyWith(isPlaying: playerState.playing);

      // When audio finishes, go back to the start
      if (playerState.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        state = state.copyWith(position: Duration.zero);
      }
    });

    // Current position changes (moves the waveform)
    final positionSub = _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    ref.onDispose(() {
      stateSub.cancel();
      positionSub.cancel();
      _player.dispose();
    });

    // Before loading, show the duration that was saved in the database
    return VoicePlayerState(total: Duration(seconds: arg.seconds));
  }

  // Download/prepare the audio only when the user first needs it
  Future<void> _loadIfNeeded() async {
    if (_isLoaded) return;
    await _player.setUrl(arg.url);
    final duration = _player.duration;
    if (duration != null) {
      state = state.copyWith(total: duration);
    }
    _isLoaded = true;
  }

  Future<void> togglePlay() async {
    await _loadIfNeeded();
    if (state.isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  // Tapping the speed button: 1x -> 1.5x -> 2x -> back to 1x
  Future<void> cycleSpeed() async {
    final currentIndex = _speeds.indexOf(state.speed);
    final nextSpeed = _speeds[(currentIndex + 1) % _speeds.length];

    await _player.setSpeed(nextSpeed);
    state = state.copyWith(speed: nextSpeed);
  }

  // Tapping a bar jumps to that point, like WhatsApp
  Future<void> seekToBar(int barIndex, int barCount) async {
    if (arg.seconds == 0) return;
    await _loadIfNeeded();

    final fraction = barIndex / barCount;
    final newPosition = Duration(
      milliseconds: (fraction * state.total.inMilliseconds).round(),
    );
    await _player.seek(newPosition);
  }
}

final voicePlayerProvider = NotifierProvider.autoDispose
    .family<VoicePlayerNotifier, VoicePlayerState, VoiceArgs>(
  VoicePlayerNotifier.new,
);