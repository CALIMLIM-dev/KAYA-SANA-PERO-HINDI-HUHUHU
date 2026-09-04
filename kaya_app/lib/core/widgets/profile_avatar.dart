import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/*
    Somebody's picture, drawn the same way everywhere.

    There were five of these and they had all drifted. The account screen drew
    a hardcoded person icon. The employer's own profile checked whether a photo
    existed and then drew a business icon either way - so uploading one changed
    nothing, and the only difference between "has a photo" and "has none" was
    which icon you got. A job post showed the first letter of the employer's
    name. None of them rendered the image the server had been sending all
    along.

    One widget, three states, in order: the photo, then an initial, then an
    icon. The initial matters - a letter in a coloured circle reads as a person
    with no photo, while a generic icon reads as a broken image, and most
    accounts here will never upload one.
*/
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.name,
    this.radius = 24,
    this.fallbackIcon = Icons.person,
    this.background,
    this.foreground,
  });

  /// Absolute URL, or null. Empty is treated as null - the server sends "" in
  /// some payloads and a NetworkImage on an empty string throws.
  final String? imageUrl;

  /// Used for the initial when there is no photo.
  final String? name;

  final double radius;
  final IconData fallbackIcon;
  final Color? background;
  final Color? foreground;

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  String? get _initial {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = background ?? AppColors.primary.withValues(alpha: 0.1);
    final fg = foreground ?? AppColors.primary;

    if (_hasImage) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        // foregroundImage, not backgroundImage: a failed load falls through to
        // the child rather than leaving a blank circle, so a broken URL still
        // shows the initial instead of a hole.
        foregroundImage: NetworkImage(imageUrl!.trim()),
        onForegroundImageError: (_, _) {},
        child: _fallback(fg),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: _fallback(fg),
    );
  }

  Widget _fallback(Color fg) {
    final initial = _initial;

    if (initial != null) {
      return Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      );
    }

    return Icon(fallbackIcon, size: radius, color: fg);
  }
}
