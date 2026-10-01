import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'glass_theme.dart';

export 'glass_theme.dart' show GlassTheme, GlassTier;

// ---------------------------------------------------------------------------
// Optics
// ---------------------------------------------------------------------------

/// Backdrop blur with an optional saturation boost applied first, so colors
/// passing under the glass stay vivid instead of washing out to grey.
ImageFilter glassFilter(GlassTheme g, double sigma) {
  final blur = ImageFilter.blur(
    sigmaX: sigma,
    sigmaY: sigma,
    // Mirror sampling stops the bright halo at screen edges that the old
    // "no blur on chrome" workaround was avoiding.
    tileMode: TileMode.mirror,
  );
  if (g.saturation == 1) return blur;
  return ImageFilter.compose(
    outer: blur,
    inner: ColorFilter.matrix(_saturation(g.saturation)),
  );
}

List<double> _saturation(double s) {
  final r = 0.2126 * (1 - s);
  final g = 0.7152 * (1 - s);
  final b = 0.0722 * (1 - s);
  return [
    r + s, g, b, 0, 0, //
    r, g + s, b, 0, 0, //
    r, g, b + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

SystemUiOverlayStyle _overlayFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
            .copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark
            .copyWith(statusBarColor: Colors.transparent);

// ---------------------------------------------------------------------------
// Atmosphere
// ---------------------------------------------------------------------------

/// The liquid backdrop every glass layer refracts: base wash, diagonal
/// gradient and three soft light pools. Painted once and cached.
class GlassAtmosphere extends StatelessWidget {
  final Widget child;

  const GlassAtmosphere({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.maybeOf(context);
    if (g == null) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _AtmospherePainter(g)),
        ),
        // Lets sibling cards share one backdrop read (cheap list blur).
        BackdropGroup(child: child),
      ],
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  final GlassTheme g;
  const _AtmospherePainter(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = g.base);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g.gradient,
          stops: g.gradientStops,
        ).createShader(rect),
    );

    final s = size.shortestSide;
    void orb(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    orb(Offset(size.width * 0.95, size.height * 0.04), s * 0.85, g.orbs[0]);
    orb(Offset(0, size.height * 0.42), s * 0.75, g.orbs[1]);
    orb(Offset(size.width * 0.9, size.height * 0.92), s * 0.9, g.orbs[2]);
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) => old.g != g;
}

// ---------------------------------------------------------------------------
// Glass panel
// ---------------------------------------------------------------------------

/// Frosted glass panel: backdrop blur, tinted fill with a top sheen, a
/// light-catching rim and two-layer shadow that never darkens the glass.
///
/// Falls back to a plain [AppColors.surface] panel on non-glass themes.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final GlassTier tier;

  /// Overrides the tier fill (e.g. an accent-tinted card).
  final Color? color;

  /// Turn off for very long lists on low-end devices; fill + rim still read
  /// as glass over the static atmosphere.
  final bool blur;
  final bool shadow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.tier = GlassTier.card,
    this.color,
    this.blur = true,
    this.shadow = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.maybeOf(context);
    Widget content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    if (onTap != null || onLongPress != null) {
      // Ink sits above the fill but below the content.
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    Widget panel;
    if (g == null) {
      panel = DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: borderRadius,
        ),
        child: content,
      );
    } else {
      final fill = color ?? g.fillFor(tier);
      panel = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.alphaBlend(g.sheen, fill), fill],
            stops: const [0, 0.45],
          ),
        ),
        child: content,
      );

      if (blur) {
        final filter = glassFilter(g, g.blurFor(tier));
        // Cards share one backdrop read; chrome must see the cards under it.
        panel = tier == GlassTier.card
            ? BackdropFilter.grouped(filter: filter, child: panel)
            : BackdropFilter(filter: filter, child: panel);
      }

      panel = CustomPaint(
        painter: shadow ? _OuterShadowPainter(borderRadius, g.shadows) : null,
        foregroundPainter: _RimPainter(
          borderRadius,
          [
            g.rimLight,
            tier == GlassTier.chrome ? g.chromeBorder : g.cardBorder,
            g.rimShade,
          ],
        ),
        child: ClipRRect(borderRadius: borderRadius, child: panel),
      );
    }

    return margin == null ? panel : Padding(padding: margin!, child: panel);
  }
}

/// Paints shadows only *outside* the rounded rect. A normal [BoxShadow] also
/// fills the area under a translucent panel, which is what turned cards
/// muddy grey.
class _OuterShadowPainter extends CustomPainter {
  final BorderRadius radius;
  final List<BoxShadow> shadows;
  const _OuterShadowPainter(this.radius, this.shadows);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(64))
        ..addRRect(rrect),
    );
    for (final s in shadows) {
      canvas.drawRRect(
        rrect.shift(s.offset).inflate(s.spreadRadius),
        s.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.radius != radius || !listEquals(old.shadows, shadows);
}

/// 1px gradient rim — bright where light hits (top-left), fading away.
class _RimPainter extends CustomPainter {
  final BorderRadius radius;
  final List<Color> colors;
  const _RimPainter(this.radius, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      radius.toRRect(rect).deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0, 0.4, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || !listEquals(old.colors, colors);
}

// ---------------------------------------------------------------------------
// Chrome: app bars
// ---------------------------------------------------------------------------

/// Frosted fill for an [AppBar] / [SliverAppBar] `flexibleSpace`. Content
/// scrolling underneath is blurred and saturated; the tint is denser at the
/// top so the status bar and title keep AA contrast over anything.
class GlassImmersiveBar extends StatelessWidget {
  final Widget? child;

  const GlassImmersiveBar({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.maybeOf(context);
    if (g == null) {
      return ColoredBox(
        color: AppColors.background,
        child: child ?? const SizedBox.expand(),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: glassFilter(g, g.chromeBlur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [g.chromeFillTop, g.chromeFill],
            ),
            border: Border(
              bottom: BorderSide(color: g.divider, width: 0.5),
            ),
          ),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Frosted app bar. Use with `extendBodyBehindAppBar: true` (or
/// [GlassScaffold]) so content actually passes underneath it.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool? centerTitle;
  final double toolbarHeight;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle,
    this.toolbarHeight = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.maybeOf(context);
    if (g == null) {
      return AppBar(
        title: title,
        actions: actions,
        leading: leading,
        centerTitle: centerTitle,
        toolbarHeight: toolbarHeight,
        backgroundColor: AppColors.header,
        foregroundColor: AppColors.headerForeground,
        elevation: 0,
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: g.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: _overlayFor(context),
      flexibleSpace: const GlassImmersiveBar(),
      titleTextStyle: TextStyle(
        color: g.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: g.icon),
      actionsIconTheme: IconThemeData(color: g.icon),
      title: title,
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      toolbarHeight: toolbarHeight,
    );
  }
}

/// Edge-to-edge scaffold: atmosphere behind everything, body extends under
/// both the app bar and the bottom bar so the glass has something to refract.
class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.maybeOf(context) != null;
    return GlassAtmosphere(
      child: Scaffold(
        backgroundColor: glass ? Colors.transparent : AppColors.background,
        extendBody: glass,
        extendBodyBehindAppBar: glass,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chrome: bottom navigation
// ---------------------------------------------------------------------------

/// Floating frosted tab bar with a liquid pill that stretches as it travels
/// between tabs and settles with a soft overshoot.
class GlassBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;
  final List<IconData> activeIcons;
  final List<String>? labels;

  const GlassBottomNav({
    super.key,
    required this.activeIndex,
    required this.onTap,
    required this.icons,
    required this.activeIcons,
    this.labels,
  }) : assert(icons.length == activeIcons.length),
       assert(labels == null || labels.length == icons.length);

  @override
  Widget build(BuildContext context) {
    final g = GlassTheme.maybeOf(context) ??
        (AppColors.isDark ? GlassTheme.dark : GlassTheme.liquid);
    final hasLabels = labels != null;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: GlassCard(
        tier: GlassTier.chrome,
        borderRadius: const BorderRadius.all(Radius.circular(32)),
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: hasLabels ? 56 : 50,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / icons.length;
              return Stack(
                children: [
                  _LiquidPill(
                    index: activeIndex,
                    count: icons.length,
                    itemWidth: itemWidth,
                    g: g,
                  ),
                  Row(
                    children: List.generate(icons.length, (i) {
                      final selected = i == activeIndex;
                      return Expanded(
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: labels?[i],
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap(i),
                            child: _NavItem(
                              icon: selected ? activeIcons[i] : icons[i],
                              label: labels?[i],
                              selected: selected,
                              color: selected
                                  ? g.selectedForeground
                                  : g.unselectedForeground,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool selected;
  final Color color;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: const Duration(milliseconds: 220),
      builder: (context, c, _) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.0 : 0.92,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Icon(icon, size: 24, color: c),
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiquidPill extends StatelessWidget {
  final int index;
  final int count;
  final double itemWidth;
  final GlassTheme g;

  const _LiquidPill({
    required this.index,
    required this.count,
    required this.itemWidth,
    required this.g,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: index.toDouble()),
      duration: const Duration(milliseconds: 480),
      // Gentle overshoot so the pill "settles" like liquid.
      curve: const Cubic(0.34, 1.36, 0.64, 1),
      builder: (context, v, child) {
        // Stretch peaks mid-travel and is zero at rest.
        final t = v - v.floorToDouble();
        final stretch = math.sin(t * math.pi) * itemWidth * 0.3;
        final width = itemWidth + stretch;
        final maxLeft = itemWidth * count - width;
        final left = (v * itemWidth - stretch / 2).clamp(0.0, maxLeft);
        return Positioned(
          left: left,
          top: 0,
          bottom: 0,
          width: width,
          child: child!,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(g.sheen, g.selectionFill),
              g.selectionFill,
            ],
          ),
          border: Border.all(color: g.selectionBorder),
          boxShadow: [
            BoxShadow(
              color: g.selectionGlow,
              blurRadius: 18,
              spreadRadius: -2,
            ),
          ],
        ),
      ),
    );
  }
}
