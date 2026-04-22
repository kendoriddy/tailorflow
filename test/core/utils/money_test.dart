import 'package:flutter_test/flutter_test.dart';

import 'package:tailorflow_ng/core/utils/money.dart';

void main() {
  test('balance never goes negative', () {
    expect(
      clampNonNegativeBalance(agreedAmountNgn: 5000, paidSumNgn: 8000),
      0,
    );
    expect(
      clampNonNegativeBalance(agreedAmountNgn: 10_000, paidSumNgn: 2500),
      7500,
    );
  });
}
