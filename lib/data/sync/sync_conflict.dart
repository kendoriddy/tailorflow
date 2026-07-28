int? syncTimestampMillis(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool remoteTimestampWins({
  required Object? remoteTimestamp,
  required Object? localTimestamp,
}) {
  final remote = syncTimestampMillis(remoteTimestamp);
  final local = syncTimestampMillis(localTimestamp);
  if (remote == null || local == null) return false;
  return remote > local;
}
