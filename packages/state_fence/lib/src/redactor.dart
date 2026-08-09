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

  /// Creates a redactor.
  ///
  /// [sensitiveKeys] defaults to [defaultSensitiveKeys]. [redactedPlaceholder]
  /// is the string written in place of redacted values.
  const MetadataRedactor({
    this.sensitiveKeys = defaultSensitiveKeys,
    this.redactor,
    this.redactedPlaceholder = '<redacted>',
  });

  /// Returns a redacted copy of [value], recursing into maps and lists.
  ///
  /// Top-level scalars are returned unchanged. Map keys are matched
  /// case-insensitively against [sensitiveKeys].
  Object? redact(Object? value) => _redactValue(null, value);

  Object? _redactValue(String? key, Object? value) {
    if (value is Map<String, Object?>) {
      return _redactMap(value);
    }
    if (value is Map) {
      return _redactMap(Map<String, Object?>.from(value));
    }
    if (value is List) {
      return _redactList(value);
    }
    return _redactScalar(key, value);
  }

  Map<String, Object?> _redactMap(Map<String, Object?> map) {
    final result = <String, Object?>{};
    map.forEach((key, value) {
      result[key] = _redactValue(key, value);
    });
    return result;
  }

  List<Object?> _redactList(List<Object?> list) {
    return list.map((item) => _redactValue(null, item)).toList();
  }

  Object? _redactScalar(String? key, Object? value) {
    if (key != null) {
      final custom = redactor;
      if (custom != null) {
        final customResult = custom(key, value);
        if (customResult != null) {
          return customResult;
        }
      }
      final lower = key.toLowerCase();
      if (sensitiveKeys.any((s) => s.toLowerCase() == lower)) {
        return redactedPlaceholder;
      }
    }
    return value;
  }
}
