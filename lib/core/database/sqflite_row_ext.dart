extension SqfliteRowX on Map<String, Object?> {
  int requireInt(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    throw StateError('sqflite row: expected int for key "$key", got ${v.runtimeType}: $v');
  }

  int? optionalInt(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }
}
