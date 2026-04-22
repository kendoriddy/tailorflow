enum OrderStatus {
  booked,
  cutting,
  ready,
  collected;

  String get wireName => name;

  static OrderStatus parse(String raw) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => OrderStatus.booked,
    );
  }
}
