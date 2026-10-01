import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';

// The mic button. It understands 3 gestures:
//  - hold and release        -> send
//  - hold and slide UP       -> lock
//  - hold and slide LEFT     -> cancel
class VoiceMicButton extends StatefulWidget {
  final bool isRecording;
  final Future<void> Function() onStart;
  final VoidCallback onLock;
  final Future<void> Function() onCancel;
  final Future<void> Function() onSend;

  const VoiceMicButton({
    super.key,
    required this.isRecording,
    required this.onStart,
    required this.onLock,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> {
  // true once this gesture already did lock or cancel, so release does nothing
  bool _gestureHandled = false;

  // We wait for start() to finish before lock/cancel/send,
  // otherwise a very quick release could leave the recorder running
  Future<void>? _startFuture;

  static const double _cancelDistance = 100; // pixels to slide left
  static const double _lockDistance = 80; // pixels to slide up

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _gestureHandled = false;
        AppHaptics.recordStart();
        HapticFeedback.heavyImpact();
        _startFuture = widget.onStart();
      },

      // Finger is moving while still holding
      onLongPressMoveUpdate: (details) async {
        if (_gestureHandled) return;

        final dx = details.offsetFromOrigin.dx; // negative = moved left
        final dy = details.offsetFromOrigin.dy; // negative = moved up

        if (dx < -_cancelDistance) {
          _gestureHandled = true;
          await _startFuture;
          await widget.onCancel();
        } else if (dy < -_lockDistance) {
          _gestureHandled = true;
          await _startFuture;
          widget.onLock();
        }
      },

      // Finger lifted normally -> send the recording
      onLongPressEnd: (_) async {
        if (_gestureHandled) return;
        await _startFuture;
        await widget.onSend();
      },

      // Gesture got interrupted (for example by the permission dialog) -> discard
      onLongPressCancel: () async {
        if (_gestureHandled) return;
        _gestureHandled = true;

        await _startFuture;
        await widget.onCancel();
      },

      // Button grows a little while recording, like WhatsApp
      child: AnimatedScale(
        scale: widget.isRecording ? 1.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: CircleAvatar(
          radius: 22,
          backgroundColor: widget.isRecording ? Colors.red : AppColors.accent,
          child: Icon(
            widget.isRecording ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// Live bars shown while recording is locked. New bars come from the right.
class LiveWaveform extends StatelessWidget {
  final List<double> levels;

  const LiveWaveform({super.key, required this.levels});

  static const int _maxBars = 40;

  @override
  Widget build(BuildContext context) {
    // Fill the empty space on the left with tiny bars
    final missing = _maxBars - levels.length;
    final bars = [
      ...List.filled(missing > 0 ? missing : 0, 0.05),
      ...levels,
    ];

    return SizedBox(
      height: 28,
      child: Row(
        children: bars.map((level) {
          return Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 3 + 22 * level, // min 3px, max 25px
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}