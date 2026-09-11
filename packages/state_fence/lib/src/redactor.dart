/// Redacts sensitive values from metadata before export.
///
/// The default behaviour replaces values whose key matches a known set of
/// sensitive names. A custom [MetadataRedactor.redactor] callback can override
/// or extend this.
typedef Redactor = Object? Function(String key, Object? value);

/// The default set of keys whose values are redacted.
const Set<String> defaultSensitiveKeys = {
  'password',
  'token',
  'secret',
  'authorisation',
  'authorization',
  'cookie',
  'api_key',
  'apikey',
  'access_token',
  'refresh_token',
};

/// A privacy-aware redactor for metadata maps and lists.
class MetadataRedactor {
  /// Keys whose values are redacted by the default behaviour.
  final Set<String> sensitiveKeys;

  /// An optional custom callback invoked for every key-value pair.
  ///
  /// When supplied, it is called first. If it returns `null`, the default
  /// key-based behaviour is applied. Otherwise the returned value is used.
  final Redactor? redactor;

  /// The placeholder value substituted for redacted entries.
  final String redactedPlaceholder;

  /// The maximum nesting depth traversed before recursion stops.
  ///
  /// Structures deeper than this, including self-referencing ones, are
  /// truncated instead of recursed into. This keeps redaction bounded.
  final int maxDepth;

  /// The placeholder value substituted where [maxDepth] is exceeded.
  final String truncatedPlaceholder;

  /// Creates a redactor.
  ///
  /// [sensitiveKeys] defaults to [defaultSensitiveKeys]. [redactedPlaceholder]
  /// is the string written in place of redacted values. [maxDepth] bounds
  /// recursion and must be greater than zero.
  const MetadataRedactor({
    this.sensitiveKeys = defaultSensitiveKeys,
    this.redactor,
    this.redactedPlaceholder = '<redacted>',
    this.maxDepth = 16,
    this.truncatedPlaceholder = '<truncated>',
  }) : assert(maxDepth > 0, 'maxDepth must be greater than zero');

  /// Returns a redacted copy of [value], recursing into maps and iterables.
  ///
  /// Iterables other than [List], such as [Set], are returned as lists so the
  /// result is always JSON-encodable.
  ///
  /// Map keys are matched case-insensitively against [sensitiveKeys]. A
  /// sensitive key redacts its entire value, including nested maps and
  /// iterables, so structured secrets cannot leak through recursion.
  /// Top-level scalars are returned unchanged.
  ///
  /// Maps with non-`String` keys are supported: each key is converted with
  /// [Object.toString] before matching, and a `null` key becomes the string
  /// `'null'`. Recursion is bounded by [maxDepth]. Redaction never throws, so
  /// a diagnostic path can always run.
  Object? redact(Object? value) => _redactValue(null, value, 0);

  Object? _redactValue(String? key, Object? value, int depth) {
    if (key != null) {
      final custom = redactor;
      if (custom != null) {
        final customResult = custom(key, value);
        if (customResult != null) {
          return customResult;
        }
      }
      if (_isSensitive(key)) {
        // A sensitive key redacts its whole subtree, not only scalars.
        return redactedPlaceholder;
      }
    }
    if (value is Map || value is Iterable) {
      if (depth >= maxDepth) return truncatedPlaceholder;
      if (value is Map) return _redactMap(value, depth + 1);
      return _redactIterable(value as Iterable<Object?>, depth + 1);
    }
    return value;
  }

  /// Redacts [map] entry by entry, stringifying keys that are not [String]s so
  /// that maps such as `Map<int, Object?>` cannot throw during redaction.
  Map<String, Object?> _redactMap(Map<Object?, Object?> map, int depth) {
    final result = <String, Object?>{};
    map.forEach((key, value) {
      final name = key is String ? key : '$key';
      result[name] = _redactValue(name, value, depth);
    });
    return result;
  }

  List<Object?> _redactIterable(Iterable<Object?> items, int depth) {
    return items.map((item) => _redactValue(null, item, depth)).toList();
  }

  bool _isSensitive(String key) {
    final lower = key.toLowerCase();
    return sensitiveKeys.any((s) => s.toLowerCase() == lower);
  }
}
