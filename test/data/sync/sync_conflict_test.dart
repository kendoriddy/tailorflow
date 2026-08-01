import 'package:flutter_test/flutter_test.dart';
import 'package:tailorflow_ng/data/sync/sync_conflict.dart';

void main() {
  group('remoteTimestampWins', () {
    test('remote row wins when it is newer than the local outbox payload', () {
      expect(
        remoteTimestampWins(remoteTimestamp: 2000, localTimestamp: 1000),
        isTrue,
      );
    });

    test('local write proceeds when it is as new or newer', () {
      expect(
        remoteTimestampWins(remoteTimestamp: 1000, localTimestamp: 1000),
        isFalse,
      );
      expect(
        remoteTimestampWins(remoteTimestamp: 1000, localTimestamp: 2000),
        isFalse,
      );
    });

    test('invalid timestamps do not skip writes', () {
      expect(
        remoteTimestampWins(remoteTimestamp: null, localTimestamp: 1000),
        isFalse,
      );
      expect(
        remoteTimestampWins(remoteTimestamp: 2000, localTimestamp: 'bad'),
        isFalse,
      );
    });
  });
}
