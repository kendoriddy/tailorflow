int clampNonNegativeBalance({required int agreedAmountNgn, required int paidSumNgn}) {
  return (agreedAmountNgn - paidSumNgn).clamp(0, 1 << 62);
}
