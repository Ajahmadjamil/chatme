import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/controller.dart';

/// Shown to the person being called: Accept / Decline.
class IncomingCallView extends ConsumerWidget {
  const IncomingCallView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callControllerProvider).call;
    final controller = ref.read(callControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white12,
              child: Icon(Icons.person, size: 64, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Text(
              call?.peerName ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              call?.isVideo == true
                  ? 'Incoming video call...'
                  : 'Incoming audio call...',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(
                    icon: Icons.call_end,
                    color: Colors.redAccent,
                    label: 'Decline',
                    onTap: controller.rejectCall,
                  ),
                  _RoundButton(
                    icon: call?.isVideo == true ? Icons.videocam : Icons.call,
                    color: Colors.green,
                    label: 'Accept',
                    onTap: controller.acceptCall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 56),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}