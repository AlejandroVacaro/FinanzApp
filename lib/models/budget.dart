import 'package:equatable/equatable.dart';

class Budget extends Equatable {
  final String id;
  final int month;
  final int year;
  final Map<String, double> categoryLimits; // CategoryId -> Límite
  final double totalLimit;

  const Budget({
    required this.id,
    required this.month,
    required this.year,
    required this.categoryLimits,
    required this.totalLimit,
  });

  @override
  List<Object?> get props => [id, month, year, categoryLimits, totalLimit];

  factory Budget.fromMap(Map<String, dynamic> map, String id) {
    return Budget(
      id: id,
      month: map['month'] ?? DateTime.now().month,
      year: map['year'] ?? DateTime.now().year,
      categoryLimits: Map<String, double>.from(map['categoryLimits'] ?? {}),
      totalLimit: (map['totalLimit'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'year': year,
      'categoryLimits': categoryLimits,
      'totalLimit': totalLimit,
    };
  }
}
