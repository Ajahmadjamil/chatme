import 'package:flutter/material.dart';

/// Circular 1:1 avatar with network image + letter fallback (WhatsApp-style).
class UserAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? fallbackIcon;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 24,
    this.backgroundColor,
    this.foregroundColor,
    this.fallbackIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.teal.shade100;
    final fg = foregroundColor ?? Colors.teal.shade800;
    final hasImage = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      // Force square crop into circle via BoxFit.cover semantics of NetworkImage
      backgroundImage: hasImage ? NetworkImage(avatarUrl!) : null,
      onBackgroundImageError: hasImage ? (_, __) {} : null,
      child: hasImage
          ? null
          : (fallbackIcon != null
              ? Icon(fallbackIcon, color: fg, size: radius)
              : Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: fg,
                    fontSize: radius * 0.85,
                    fontWeight: FontWeight.w700,
                  ),
                )),
    );

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }
}
