/// Paystack plan amounts (must match plans in your Paystack dashboard).
abstract final class SubscriptionPricing {
  static const int monthlyNgn = 2000;
  static const int yearlyNgn = 19800;

  static const int monthlyKobo = monthlyNgn * 100;
  static const int yearlyKobo = yearlyNgn * 100;

  static String labelMonthly() => '₦${_format(monthlyNgn)}/month';
  static String labelYearly() => '₦${_format(yearlyNgn)}/year';

  static String _format(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

enum SubscriptionPlan { monthly, yearly }

extension SubscriptionPlanX on SubscriptionPlan {
  String get apiValue => name;

  String get displayLabel {
    switch (this) {
      case SubscriptionPlan.monthly:
        return SubscriptionPricing.labelMonthly();
      case SubscriptionPlan.yearly:
        return SubscriptionPricing.labelYearly();
    }
  }
}
