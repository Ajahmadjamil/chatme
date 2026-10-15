import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../controller/controller.dart';
import '../model/calling_model.dart';


/// The screen during a call (also shows "Calling...", "Call ended", ...).
class ActiveCallView extends ConsumerWidget {
  const ActiveCallView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final isVideo = state.call?.isVideo == true;

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1) Background: other person's video, or an avatar.
          if (isVideo && state.hasRemoteVideo)
            RTCVideoView(
              controller.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            const Center(
              child: CircleAvatar(
                radius: 64,
                backgroundColor: Colors.white12,
                child: Icon(Icons.person, size: 72, color: Colors.white70),
              ),
            ),

          // 2) Top: name and status text.
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.call?.peerName ?? 'Call',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _statusText(state),
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3) Top-right: my own small camera preview.
          if (isVideo && state.hasLocalVideo)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 110,
                  height: 160,
                  margin: const EdgeInsets.all(12),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: state.isCameraOn
                      ? RTCVideoView(
                    controller.localRenderer,
                    mirror: state.isFrontCamera,
                    objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                      : const Center(
                    child:
                    Icon(Icons.videocam_off, color: Colors.white54),
                  ),
                ),
              ),
            ),

          // 4) Bottom: control buttons.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _ControlButton(
                      icon: state.isMuted ? Icons.mic_off : Icons.mic,
                      highlighted: state.isMuted,
                      onTap: controller.toggleMute,
                    ),
                    if (isVideo) ...[
                      _ControlButton(
                        icon: state.isCameraOn
                            ? Icons.videocam
                            : Icons.videocam_off,
                        highlighted: !state.isCameraOn,
                        onTap: controller.toggleCamera,
                      ),
                      _ControlButton(
                        icon: Icons.cameraswitch,
                        onTap: controller.switchCamera,
                      ),
                    ],
                    _ControlButton(
                      icon: state.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.hearing,
                      highlighted: state.isSpeakerOn,
                      onTap: controller.toggleSpeaker,
                    ),
                    _ControlButton(
                      icon: Icons.call_end,
                      color: Colors.redAccent,
                      onTap: controller.endCall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(CallUiState state) {
    switch (state.status) {
      case CallState.initiating:
        return 'Calling...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.connecting:
        return 'Connecting...';
      case CallState.connected:
        return _formatDuration(state.duration);
      case CallState.reconnecting:
        return 'Reconnecting...';
      case CallState.busy:
        return 'User is busy';
      case CallState.ended:
        return state.endReason ?? 'Call ended';
      case CallState.idle:
        return '';
    }
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? (highlighted ? Colors.white : Colors.white24),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(
            icon,
            size: 28,
            color:
            (color == null && highlighted) ? Colors.black87 : Colors.white,
          ),
        ),
      ),
    );
  }
}