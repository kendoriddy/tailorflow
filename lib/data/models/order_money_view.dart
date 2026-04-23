import 'order_row.dart';

class OrderMoneyView {
  const OrderMoneyView({
    required this.order,
    required this.paidNgn,
    required this.balanceNgn,
  });

  final OrderRow order;
  final int paidNgn;
  final int balanceNgn;
}
