import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/services/api_client.dart';
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
/*
    A photo decoded at the size it is drawn.

    Photos go up at 1024 pixels, and a 26-radius circle draws about 150 of
    them on a 3x phone. Without a size the whole 1024x1024 was decoded and
    kept - 4 MB of memory per face, so a list of twenty workers held 80 MB
    of pixels to show circles the size of a thumbnail.

    And a stored path made into an address. users.avatar holds each
    account's latest picture as a path ("profile_photos/x.jpg"), and every
    payload that embeds a user row as it is sends that path. A path is not
    a URL, the image failed, and the circle fell back to a letter for
    somebody who had a photo - in reviews, in My Applications, wherever a
    user arrived embedded rather than through resolvedAvatarUrl.

    And kept on the phone. A plain NetworkImage is held in memory per size,
    so the same face at chat size, list size and profile size was three
    downloads of a 150 KB photo - the circle showed a letter while each one
    came in, and again after the app restarted. Cached to disk once by URL,
    every size after the first is read from the phone.
*/
ImageProvider avatarImage(BuildContext context, String url, double radius) =>
    ResizeImage.resizeIfNeeded(
      (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round(),
      null,
      CachedNetworkImageProvider(ApiClient.fileUrl(url.trim())),
    );

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
        foregroundImage: avatarImage(context, imageUrl!, radius),
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
