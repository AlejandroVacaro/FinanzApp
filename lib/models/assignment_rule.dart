import 'package:equatable/equatable.dart';

class AssignmentRule extends Equatable {
  final String id;
  final String pattern; // Texto a buscar en la descripción (ej: "UBER", "NETFLIX")
  final String targetCategoryId; // ID de la categoría a asignar
  final int priority; // Para resolver conflictos (mayor número = mayor prioridad)
  final bool isActive;

  const AssignmentRule({
    required this.id,
    required this.pattern,
    required this.targetCategoryId,
    this.priority = 1,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, pattern, targetCategoryId, priority, isActive];

  factory AssignmentRule.fromMap(Map<String, dynamic> map, String id) {
    return AssignmentRule(
      id: id,
      pattern: map['pattern'] ?? '',
      targetCategoryId: map['targetCategoryId'] ?? '',
      priority: map['priority'] ?? 1,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pattern': pattern,
      'targetCategoryId': targetCategoryId,
      'priority': priority,
      'isActive': isActive,
    };
  }
}
