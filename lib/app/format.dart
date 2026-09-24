import 'dart:math';

import 'package:routeros/routeros.dart';

/// Compact duration for stats: `3d 4h`, `4h 12m`, `12m` or `45s`.
String formatDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours % 24}h';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  if (duration.inMinutes > 0) return '${duration.inMinutes}m';
  return '${duration.inSeconds}s';
}

/// Lowercase like RouterOS prints it, in blocks of 8 with two blocks per
/// line, so it's easy to compare.
String groupFingerprint(String fingerprint) {
  final hex = normalizeFingerprint(fingerprint);
  final blocks = [
    for (var i = 0; i < hex.length; i += 8)
      hex.substring(i, min(i + 8, hex.length)),
  ];
  return [
    for (var i = 0; i < blocks.length; i += 2) blocks.skip(i).take(2).join(' '),
  ].join('\n');
}

/// `/CN=watchtower` becomes `CN=watchtower`.
String distinguishedName(String name) =>
    name.startsWith('/') ? name.substring(1) : name;

/// RouterOS writes superscripts with a caret: `hAP ax^3` becomes `hAP ax³`.
String formatBoardName(String name) =>
    name.replaceAll('^2', '²').replaceAll('^3', '³');
