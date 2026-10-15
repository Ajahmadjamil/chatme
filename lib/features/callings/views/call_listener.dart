import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/controller.dart';
import '../model/calling_model.dart';
import 'active_call_view.dart';
import 'incoming_call_view.dart';

/// Wrap the whole app with this widget (MaterialApp `builder`).
/// It watches the call status and opens/closes the call screen on ANY page.
class CallListener extends ConsumerStatefulWidget {
  const CallListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<CallListener> createState() => _CallListenerState();
}

class _CallListenerState extends ConsumerState<CallListener> {
  bool _screenOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<CallState>(
      callControllerProvider.select((s) => s.status),
          (previous, next) {
        final navigator = widget.navigatorKey.currentState;
        if (navigator == null) return;

        if (next != CallState.idle && !_screenOpen) {
          _screenOpen = true;
          navigator
              .push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const CallScreen(),
          ))
              .whenComplete(() => _screenOpen = false);
        } else if (next == CallState.idle && _screenOpen) {
          navigator.pop();
        }
      },
    );

    return widget.child;
  }
}

/// Incoming (not answered yet) -> Accept/Decline. Otherwise -> active call.
class CallScreen extends ConsumerWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    final call = state.call;

    final isRingingIncoming = call != null &&
        call.direction == CallDirection.incoming &&
        state.status == CallState.ringing;

    return isRingingIncoming
        ? const IncomingCallView()
        : const ActiveCallView();
  }
}