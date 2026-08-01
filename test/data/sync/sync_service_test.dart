import 'package:flutter_test/flutter_test.dart';
import 'package:tailorflow_ng/data/sync/sync_service.dart';

void main() {
  group('SyncService.collectPagedRows', () {
    test('keeps fetching until a short final page', () async {
      final ranges = <String>[];

      final rows = await SyncService.collectPagedRows(
        pageSize: 2,
        fetchPage: (from, to) async {
          ranges.add('$from-$to');
          if (from == 0) return ['a', 'b'];
          if (from == 2) return ['c', 'd'];
          return ['e'];
        },
      );

      expect(rows, ['a', 'b', 'c', 'd', 'e']);
      expect(ranges, ['0-1', '2-3', '4-5']);
    });

    test('checks the next range after an exact-sized page', () async {
      final ranges = <String>[];

      final rows = await SyncService.collectPagedRows(
        pageSize: 2,
        fetchPage: (from, to) async {
          ranges.add('$from-$to');
          if (from == 0) return ['a', 'b'];
          return [];
        },
      );

      expect(rows, ['a', 'b']);
      expect(ranges, ['0-1', '2-3']);
    });

    test('rejects invalid page sizes', () {
      expect(
        SyncService.collectPagedRows(
          pageSize: 0,
          fetchPage: (_, _) async => [],
        ),
        throwsArgumentError,
      );
    });
  });
}
