/// Polite, short templates suitable for Nigerian shop-floor tone.
class WhatsAppTemplates {
  static String dressReady({
    required String customerName,
    required String styleTitle,
    String shopName = 'our shop',
  }) {
    final name = customerName.trim().isEmpty ? 'Sir/Ma' : customerName.trim();
    return 'Good day $name, your outfit ($styleTitle) is ready for pickup at '
        '$shopName. Kindly let us know when you are coming. Thank you.';
  }

  static String paymentReminder({
    required String customerName,
    required String balanceText,
  }) {
    final name = customerName.trim().isEmpty ? 'Sir/Ma' : customerName.trim();
    return 'Good day $name, friendly reminder: outstanding balance is '
        '$balanceText. Thank you.';
  }

  static String feedbackAndBirthdayRequest({
    required String customerName,
    String? orderTitle,
  }) {
    final name = customerName.trim().isEmpty ? 'Sir/Ma' : customerName.trim();
    final orderPart = (orderTitle?.trim().isNotEmpty == true)
        ? ' for your $orderTitle'
        : '';
    return 'Hello $name, thank you for patronizing us$orderPart. '
        'Please rate our service from 1-5 and share any quick feedback. '
        'Also kindly send your birthday day and month (year optional). '
        'We ask this so we can celebrate you on your birthday and give special discounts.';
  }
}
