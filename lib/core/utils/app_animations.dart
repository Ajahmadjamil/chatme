import 'dart:math' as math;
import 'package:flutter/material.dart';

// Same folder as app_haptics.dart (change the path if yours is different)
import 'app_haptics.dart';

// ============================================================
// app_animations.dart
// One place for every reusable animation / polish widget.
// No extra package needed.
//
// WIDGETS IN THIS FILE:
//  1.  FadeSlideIn          new message slides up + fades in
//  2.  Pulse                mic button pulse while recording
//  3.  BlinkingDot          red recording dot
//  4.  TypingIndicator      three bouncing dots
//  5.  SendMicSwitcher      mic <-> send icon switch
//  6.  MessageTicks         sending / sent / delivered / seen / failed
//  7.  SwipeToReply         swipe a bubble right to reply
//  8.  HighlightFlash       flash a message after jumping to it
//  9.  ScrollToBottomButton scroll-down button (scale + fade)
//  10. BounceIn             popup bounce (emoji reactions, menus)
//  11. ShimmerBox           loading skeleton
//  12. PressScale           press-down effect for tiles/buttons
//  13. UploadProgressRing   upload progress + cancel button
//  14. NoInternetBanner     slide-down offline banner
//  15. WaveformBars         waveform with progress fill + seek
//  16. PlaybackSpeedButton  1x / 1.5x / 2x toggle
//  17. SinglePlayback       only one voice note plays at a time
// ============================================================

// Common durations used everywhere
class AppAnim {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

// ------------------------------------------------------------
// 1) FADE + SLIDE IN
// Use for a NEW message only (set enabled: false for old ones,
// otherwise old messages animate again when you scroll back).
//
//   FadeSlideIn(enabled: isNewMessage, child: MessageBubble(...))
//   FadeSlideIn(offsetX: 30, offsetY: 0, child: ...)  // from the side
// ------------------------------------------------------------
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double offsetY;
  final double offsetX;
  final bool enabled;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = AppAnim.normal,
    this.offsetY = 20,
    this.offsetX = 0,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Tree stays the same even when disabled (zero duration = no animation),
    // so the child never loses its state (e.g. a playing voice note).
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: enabled ? duration : Duration.zero,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(offsetX * (1 - value), offsetY * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 2) PULSE
// Grows and shrinks its child again and again while active.
//
//   Pulse(active: isRecording, child: MicButton())
// ------------------------------------------------------------
class Pulse extends StatefulWidget {
  final Widget child;
  final bool active;
  final double minScale;
  final double maxScale;
  final Duration duration;

  const Pulse({
    super.key,
    required this.child,
    this.active = true,
    this.minScale = 1.0,
    this.maxScale = 1.25,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: widget.minScale, end: widget.maxScale)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant Pulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

// ------------------------------------------------------------
// 3) BLINKING DOT
// Red dot that blinks next to the recording timer.
//
//   Row(children: [BlinkingDot(), SizedBox(width: 8), Text('0:05')])
// ------------------------------------------------------------
class BlinkingDot extends StatefulWidget {
  final double size;
  final Color color;

  const BlinkingDot({super.key, this.size = 10, this.color = Colors.red});

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.2, end: 1.0).animate(_controller),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ------------------------------------------------------------
// 4) TYPING INDICATOR
// Three dots that bounce like a wave.
//
//   if (otherUserIsTyping) TypingIndicator()
// ------------------------------------------------------------
class TypingIndicator extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const TypingIndicator({super.key, this.color, this.dotSize = 7});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.grey;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is a little behind the previous one (wave effect)
            final wave = math.sin(_controller.value * 2 * math.pi - i * 0.9);
            final dy = -4 * math.max(0.0, wave);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0.0, dy.toDouble()),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 5) SEND / MIC SWITCHER
// Mic changes to send (and back) with scale + fade.
//
//   SendMicSwitcher(
//     showSend: textController.text.trim().isNotEmpty,
//     sendButton: SendButton(),
//     micButton: MicButton(),
//   )
// ------------------------------------------------------------
class SendMicSwitcher extends StatelessWidget {
  final bool showSend;
  final Widget sendButton;
  final Widget micButton;

  const SendMicSwitcher({
    super.key,
    required this.showSend,
    required this.sendButton,
    required this.micButton,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppAnim.fast,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: showSend
          ? KeyedSubtree(key: const ValueKey('send'), child: sendButton)
          : KeyedSubtree(key: const ValueKey('mic'), child: micButton),
    );
  }
}

// ------------------------------------------------------------
// 6) MESSAGE TICKS
// Icon changes smoothly when the status changes.
//
//   MessageTicks(status: MessageStatus.seen)
// ------------------------------------------------------------
enum MessageStatus { sending, sent, delivered, seen, failed }

class MessageTicks extends StatelessWidget {
  final MessageStatus status;
  final double size;
  final Color idleColor;
  final Color seenColor;

  const MessageTicks({
    super.key,
    required this.status,
    this.size = 16,
    this.idleColor = Colors.grey,
    this.seenColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color = idleColor;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        break;
      case MessageStatus.seen:
        icon = Icons.done_all;
        color = seenColor;
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }

    return AnimatedSwitcher(
      duration: AppAnim.fast,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Icon(icon, key: ValueKey(status), size: size, color: color),
    );
  }
}

// ------------------------------------------------------------
// 7) SWIPE TO REPLY
// Swipe a bubble to the right: it follows the finger, a reply icon
// grows, a haptic fires at the threshold, and on release it springs back.
//
//   SwipeToReply(
//     onReply: () => startReply(message),
//     child: MessageBubble(...),
//   )
// ------------------------------------------------------------
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final double threshold;
  final Color iconColor;
  final bool enabled;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.threshold = 60,
    this.iconColor = Colors.grey,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _back;
  Animation<double>? _backAnim;
  double _dx = 0;
  bool _passed = false;

  @override
  void initState() {
    super.initState();
    _back = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
      if (_backAnim != null) {
        setState(() => _dx = math.max(0.0, _backAnim!.value));
      }
    });
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_back.isAnimating) _back.stop();
    setState(() {
      _dx = (_dx + details.delta.dx).clamp(0.0, widget.threshold * 1.4).toDouble();
    });
    if (_dx >= widget.threshold && !_passed) {
      _passed = true;
      AppHaptics.medium();
    } else if (_dx < widget.threshold) {
      _passed = false;
    }
  }

  void _onEnd(DragEndDetails details) {
    if (_passed) widget.onReply();
    _passed = false;
    _backAnim = Tween<double>(begin: _dx, end: 0).animate(
      CurvedAnimation(parent: _back, curve: Curves.easeOutBack),
    );
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final progress = (_dx / widget.threshold).clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: progress,
                    child: Icon(Icons.reply, color: widget.iconColor),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 8) HIGHLIGHT FLASH
// Parent sets highlighted = true, then false after ~1.5 sec.
//
//   HighlightFlash(
//     highlighted: highlightedMessageId == message.id,
//     child: MessageBubble(...),
//   )
//
//   // after scrolling to the original message:
//   setState(() => highlightedMessageId = id);
//   Future.delayed(const Duration(milliseconds: 1500), () {
//     if (mounted) setState(() => highlightedMessageId = null);
//   });
// ------------------------------------------------------------
class HighlightFlash extends StatelessWidget {
  final bool highlighted;
  final Widget child;
  final Color color;

  const HighlightFlash({
    super.key,
    required this.highlighted,
    required this.child,
    this.color = const Color(0x55FFC107),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: highlighted ? color : Colors.transparent,
      child: child,
    );
  }
}

// ------------------------------------------------------------
// 9) SCROLL TO BOTTOM BUTTON
// Put it in a Stack on top of the message list.
//
//   Positioned(
//     right: 12, bottom: 12,
//     child: ScrollToBottomButton(visible: showButton, onTap: scrollDown),
//   )
//
// showButton: listen to the ScrollController and set it when the user
// is far from the latest message.
// ------------------------------------------------------------
class ScrollToBottomButton extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;

  const ScrollToBottomButton({
    super.key,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0,
        duration: AppAnim.fast,
        curve: visible ? Curves.easeOutBack : Curves.easeIn,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: AppAnim.fast,
          child: FloatingActionButton.small(
            onPressed: () {
              AppHaptics.tap();
              onTap();
            },
            child: const Icon(Icons.keyboard_arrow_down),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 10) BOUNCE IN
// Pops in with a springy bounce (reaction bar, popup menus).
//
//   BounceIn(child: ReactionBar())
// ------------------------------------------------------------
class BounceIn extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const BounceIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.elasticOut,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: value, child: child),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// 11) SHIMMER BOX
// Loading skeleton, no package needed.
//
//   ShimmerBox(width: 200, height: 14)
//   ShimmerBox(width: 48, height: 48, borderRadius: 24)  // avatar
// ------------------------------------------------------------
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [base, highlight, base],
                stops: const [0.35, 0.5, 0.65],
                transform: _SlidingGradientTransform(_controller.value),
              ).createShader(bounds);
            },
            child: Container(
              width: widget.width,
              height: widget.height,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

// Moves the shimmer gradient from left to right
class _SlidingGradientTransform extends GradientTransform {
  final double percent;
  const _SlidingGradientTransform(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 2 - 1), 0, 0);
  }
}

// ------------------------------------------------------------
// 12) PRESS SCALE
// Small shrink while the finger is down (chat tiles, buttons).
//
//   PressScale(onTap: openChat, child: ChatTile(...))
// ------------------------------------------------------------
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

// ------------------------------------------------------------
// 13) UPLOAD PROGRESS RING
// Put inside the bubble while an image/voice note uploads.
// progress: 0.0 to 1.0 (null = spinning without a value)
//
//   UploadProgressRing(progress: 0.4, onCancel: cancelUpload)
// ------------------------------------------------------------
class UploadProgressRing extends StatelessWidget {
  final double? progress;
  final VoidCallback? onCancel;
  final double size;
  final Color color;

  const UploadProgressRing({
    super.key,
    this.progress,
    this.onCancel,
    this.size = 40,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress == null)
            CircularProgressIndicator(strokeWidth: 2.5, color: color)
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress!.clamp(0.0, 1.0).toDouble()),
              duration: AppAnim.normal,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 2.5,
                  color: color,
                );
              },
            ),
          if (onCancel != null)
            GestureDetector(
              onTap: () {
                AppHaptics.light();
                onCancel!();
              },
              child: Icon(Icons.close, size: size * 0.45, color: color),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// 14) NO INTERNET BANNER
// Put at the top of the screen (inside a Column). Slides open/closed.
//
//   NoInternetBanner(visible: !isOnline)
// ------------------------------------------------------------
class NoInternetBanner extends StatelessWidget {
  final bool visible;
  final String text;

  const NoInternetBanner({
    super.key,
    required this.visible,
    this.text = 'No internet connection',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppAnim.normal,
      curve: Curves.easeOut,
      child: visible
          ? Container(
        width: double.infinity,
        color: Colors.red.shade700,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

// ------------------------------------------------------------
// 15) WAVEFORM BARS
// Bars fill with color as the audio plays. Tap or drag to seek.
// samples: values from 0.0 to 1.0 (saved from recording amplitude)
// progress: 0.0 to 1.0 (position / duration)
// Give it a bounded width (inside Expanded or SizedBox).
//
//   WaveformBars(
//     samples: message.waveform,
//     progress: position / duration,
//     onSeek: (p) => player.seek(duration * p),
//   )
// ------------------------------------------------------------
class WaveformBars extends StatelessWidget {
  final List<double> samples;
  final double progress;
  final ValueChanged<double>? onSeek;
  final Color activeColor;
  final Color inactiveColor;
  final double height;
  final double barWidth;
  final double gap;

  const WaveformBars({
    super.key,
    required this.samples,
    required this.progress,
    this.onSeek,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.height = 32,
    this.barWidth = 3,
    this.gap = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void seek(double dx) {
          if (onSeek == null || width <= 0) return;
          onSeek!((dx / width).clamp(0.0, 1.0).toDouble());
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
          child: CustomPaint(
            size: Size(width, height),
            painter: _WaveformPainter(
              samples: samples,
              progress: progress.clamp(0.0, 1.0).toDouble(),
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              barWidth: barWidth,
              gap: gap,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double barWidth;
  final double gap;

  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.barWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0) return;

    final barCount = (size.width / (barWidth + gap)).floor();
    if (barCount <= 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      // Pick the matching sample for this bar
      final int sampleIndex =
      math.min(samples.length - 1, ((i / barCount) * samples.length).floor());
      final value = samples[sampleIndex].clamp(0.0, 1.0).toDouble();
      final barHeight = math.max(3.0, value * size.height);

      final x = i * (barWidth + gap);
      final top = (size.height - barHeight) / 2;

      paint.color = (i / barCount) < progress ? activeColor : inactiveColor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.progress != progress ||
        old.samples != samples ||
        old.activeColor != activeColor ||
        old.inactiveColor != inactiveColor;
  }
}

// ------------------------------------------------------------
// 16) PLAYBACK SPEED BUTTON
// Tap to cycle 1x -> 1.5x -> 2x -> 1x.
//
//   PlaybackSpeedButton(speed: speed, onChanged: (s) => player.setSpeed(s))
// ------------------------------------------------------------
class PlaybackSpeedButton extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;
  final Color? color;

  const PlaybackSpeedButton({
    super.key,
    required this.speed,
    required this.onChanged,
    this.color,
  });

  static const List<double> speeds = [1.0, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final label = speed == speed.roundToDouble() ? '${speed.toInt()}x' : '${speed}x';

    return GestureDetector(
      onTap: () {
        AppHaptics.tap();
        final index = speeds.indexOf(speed);
        onChanged(speeds[(index + 1) % speeds.length]);
      },
      child: AnimatedContainer(
        duration: AppAnim.fast,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// 17) SINGLE PLAYBACK
// Only one voice note plays at a time. When a new one starts,
// the old one is stopped automatically.
//
// In your player (when playback starts):
//   SinglePlayback.started(stopMe);   // stopMe = the function that stops THIS player
// When it finishes or is stopped:
//   SinglePlayback.finished(stopMe);
// ------------------------------------------------------------
class SinglePlayback {
  static VoidCallback? _stopCurrent;

  static void started(VoidCallback stopFn) {
    if (_stopCurrent != null && _stopCurrent != stopFn) {
      _stopCurrent!();
    }
    _stopCurrent = stopFn;
  }

  static void finished(VoidCallback stopFn) {
    if (_stopCurrent == stopFn) _stopCurrent = null;
  }
}