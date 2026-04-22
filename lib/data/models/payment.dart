class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.amountNgn,
    required this.paidAt,
    this.note,
  });

  final String id;
  final String orderId;
  final int amountNgn;
  final DateTime paidAt;
  final String? note;
}
