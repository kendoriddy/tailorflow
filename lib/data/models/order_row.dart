import 'order_status.dart';

class OrderRow {
  const OrderRow({
    required this.id,
    required this.customerId,
    required this.title,
    this.fabricNote,
    required this.dueDate,
    required this.status,
    required this.agreedAmountNgn,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String title;
  final String? fabricNote;
  final DateTime dueDate;
  final OrderStatus status;
  final int agreedAmountNgn;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class OrderDueView extends OrderRow {
  const OrderDueView({
    required super.id,
    required super.customerId,
    required super.title,
    super.fabricNote,
    required super.dueDate,
    required super.status,
    required super.agreedAmountNgn,
    required super.createdAt,
    required super.updatedAt,
    required this.customerName,
    required this.balanceNgn,
  });

  final String customerName;
  final int balanceNgn;
}
