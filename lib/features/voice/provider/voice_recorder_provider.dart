import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_recorder.dart';

// What the UI needs to know while recording
class VoiceRecorderState {
  final bool isRecording;
  final bool isLocked; // true after the user slides up
  final int seconds;
  final List<double> levels; // loudness values from 0.0 to 1.0, newest last

  const VoiceRecorderState({
    this.isRecording = false,
    this.isLocked = false,
    this.seconds = 0,
    this.levels = const [],
  });

  VoiceRecorderState copyWith({bool? isLocked, int? seconds, List<double>? levels}) {
    return VoiceRecorderState(
      isRecording: isRecording,
      isLocked: isLocked ?? this.isLocked,
      seconds: seconds ?? this.seconds,
      levels: levels ?? this.levels,
    );
  }
}

class VoiceRecorderNotifier extends Notifier<VoiceRecorderState> {
  late VoiceRecorderService _service;
  Timer? _timer;
  StreamSubscription? _amplitudeSub;

  @override
  VoiceRecorderState build() {
    _service = VoiceRecorderService();

    ref.onDispose(() {
      _stopListening();
      _service.dispose();
    });

    return const VoiceRecorderState();
  }

  // Returns false if mic permission was denied or recording failed to start
  Future<bool> start() async {
    final started = await _service.startRecording();
    if (!started) return false;

    state = const VoiceRecorderState(isRecording: true);

    // Tick every second for the live timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(seconds: state.seconds + 1);
    });

    // Listen to mic loudness for the live waveform
    _amplitudeSub = _service.amplitudeStream().listen((amp) {
      if (!state.isRecording) return;
      // amp.current is in dB (about -160 to 0). Convert it to 0.0 - 1.0
      final level = ((amp.current + 50) / 50).clamp(0.0, 1.0);
      final newLevels = [...state.levels, level];
      if (newLevels.length > 40) newLevels.removeAt(0); // keep only last 40 bars
      state = state.copyWith(levels: newLevels);
    });

    return true;
  }

  // User slid up: keep recording even after the finger is lifted
  void lock() {
    if (state.isRecording) {
      state = state.copyWith(isLocked: true);
    }
  }

  // Stops recording and returns the file + duration (null if too short)
  Future<VoiceRecordResult?> stop() async {
    if (!state.isRecording) return null; // already stopped, ignore
    _stopListening();
    state = const VoiceRecorderState(); // switch UI back to normal first
    return _service.stopRecording();
  }

  // Stops recording and deletes the file (slide left / trash button)
  Future<void> cancel() async {
    if (!state.isRecording) return;
    _stopListening();
    state = const VoiceRecorderState();
    await _service.cancelRecording();
  }

  void _stopListening() {
    _timer?.cancel();
    _timer = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }
}

final voiceRecorderProvider =
NotifierProvider.autoDispose<VoiceRecorderNotifier, VoiceRecorderState>(
  VoiceRecorderNotifier.new,
);