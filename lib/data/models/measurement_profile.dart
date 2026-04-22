class MeasurementProfile {
  const MeasurementProfile({
    required this.id,
    required this.customerId,
    required this.label,
    this.chest,
    this.waist,
    this.length,
    this.sleeve,
    this.shoulder,
    this.neck,
    this.inseam,
    this.notes,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final String label;
  final double? chest;
  final double? waist;
  final double? length;
  final double? sleeve;
  final double? shoulder;
  final double? neck;
  final double? inseam;
  final String? notes;
  final DateTime updatedAt;
}
