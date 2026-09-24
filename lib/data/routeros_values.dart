final _durationPart = RegExp(r'(\d+)(ms|w|d|h|m|s)');

/// Parses a RouterOS duration such as `1w2d3h4m5s` or `15s20ms`. Returns
/// null for anything else, e.g. `never`.
Duration? parseRouterOsDuration(String? value) {
  if (value == null || value.isEmpty) return null;
  var total = Duration.zero;
  var end = 0;
  for (final match in _durationPart.allMatches(value)) {
    if (match.start != end) return null;
    end = match.end;
    final n = int.parse(match[1]!);
    total += switch (match[2]) {
      'w' => Duration(days: 7 * n),
      'd' => Duration(days: n),
      'h' => Duration(hours: n),
      'm' => Duration(minutes: n),
      's' => Duration(seconds: n),
      _ => Duration(milliseconds: n),
    };
  }
  return end == value.length ? total : null;
}
