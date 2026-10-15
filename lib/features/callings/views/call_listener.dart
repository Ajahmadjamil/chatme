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
  // The call screen we pushed. Kept so we close exactly that screen, not
  // whatever happens to be on top (a dialog, a sheet, another page).
  Route<void>? _route;

  @override
  Widget build(BuildContext context) {
    ref.listen<CallState>(
      callControllerProvider.select((s) => s.status),
          (previous, next) {
        final navigator = widget.navigatorKey.currentState;
        if (navigator == null) return;

        final route = _route;
        final screenOpen = route != null && route.isActive;

        if (next == CallState.idle) {
          if (screenOpen) navigator.removeRoute(route);
          _route = null;
        } else if (!screenOpen) {
          final newRoute = MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const CallScreen(),
          );
          _route = newRoute;
          navigator.push(newRoute).whenComplete(() {
            if (_route == newRoute) _route = null;
          });
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

    // While a call is going on, Back must not close this screen — the call
    // would keep running with no way to hang up. Use the red button instead.
    return PopScope(
      canPop: !state.isInCall,
      child: isRingingIncoming
          ? const IncomingCallView()
          : const ActiveCallView(),
    );
  }
}