import 'order_status.dart';
import 'order_attachment.dart';

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
    this.attachments = const <OrderAttachment>[],
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
  final List<OrderAttachment> attachments;
}
