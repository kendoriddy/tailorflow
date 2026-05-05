class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.phoneNorm,
    required this.createdAt,
    required this.updatedAt,
    required this.birthDay,
    required this.birthMonth,
    required this.birthYear,
    required this.birthdayConsent,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String phoneNorm;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? birthDay;
  final int? birthMonth;
  final int? birthYear;
  final bool birthdayConsent;
  final DateTime? deletedAt;

  bool get isActive => deletedAt == null;

  String? get birthdayDisplay {
    if (birthDay == null || birthMonth == null) return null;
    final dd = birthDay!.toString().padLeft(2, '0');
    final mm = birthMonth!.toString().padLeft(2, '0');
    if (birthYear == null) return '$dd/$mm';
    return '$dd/$mm/$birthYear';
  }
}
