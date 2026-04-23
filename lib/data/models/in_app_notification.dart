class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.kind,
    required this.dueDate,
    required this.fireOn,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String orderId;
  final String customerId;
  final String kind;
  final DateTime dueDate;
  final DateTime fireOn;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;
}

class InAppNotificationView extends InAppNotification {
  const InAppNotificationView({
    required super.id,
    required super.orderId,
    required super.customerId,
    required super.kind,
    required super.dueDate,
    required super.fireOn,
    required super.title,
    required super.body,
    required super.createdAt,
    required super.readAt,
    required this.customerName,
    required this.orderTitle,
  });

  final String customerName;
  final String orderTitle;
}
