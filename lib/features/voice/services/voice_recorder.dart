import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  DateTime? _startTime;
  bool _isRecording = false; // simple manual flag, avoids async getter issue


  bool get isRecording => _isRecording;

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<bool> startRecording() async {
    final hasPermission = await requestMicPermission();
    if (!hasPermission) return false;

    final hasEncoderSupport = await _recorder.hasPermission();
    if (!hasEncoderSupport) return false;

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    _startTime = DateTime.now();
    _isRecording = true; // mark as recording
    return true;
  }

  Future<VoiceRecordResult?> stopRecording() async {
    final path = await _recorder.stop();
    _isRecording = false; // mark as stopped, regardless of result

    if (path == null || _startTime == null) return null;

    final duration = DateTime.now().difference(_startTime!).inSeconds;
    _startTime = null;

    final file = File(path);
    if (!await file.exists()) return null;

    if (duration < 1) {
      await file.delete();
      return null;
    }

    return VoiceRecordResult(filePath: path, durationSeconds: duration);
  }

  Future<void> cancelRecording() async {
    final path = await _recorder.stop();
    _isRecording = false;
    _startTime = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
  // Gives the loudness of the mic every 100ms (used for the live waveform)
  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  void dispose() {
    _recorder.dispose();
  }
}

class VoiceRecordResult {
  final String filePath;
  final int durationSeconds;

  VoiceRecordResult({
    required this.filePath,
    required this.durationSeconds,
  });
}