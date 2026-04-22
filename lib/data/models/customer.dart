class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.phoneNorm,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String phoneNorm;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isActive => deletedAt == null;
}
