import 'package:flutter_test/flutter_test.dart';

import 'package:tailorflow_ng/core/utils/phone.dart';

void main() {
  test('normalizes common Nigerian inputs', () {
    expect(normalizePhoneDigits('08031234567'), '2348031234567');
    expect(normalizePhoneDigits('2348031234567'), '2348031234567');
    expect(normalizePhoneDigits('8031234567'), '2348031234567');
  });
}
