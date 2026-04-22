import 'package:intl/intl.dart';

final _ngn = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

String formatNgn(int amountMinor) => _ngn.format(amountMinor);
