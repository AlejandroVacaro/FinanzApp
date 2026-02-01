import 'package:equatable/equatable.dart';

class AssignmentRule extends Equatable {
  final String id;
  String keyword; // Was 'pattern'
  String categoryId; // Was 'targetCategoryId'
  final int priority;
  final bool isActive;

  AssignmentRule({
    required this.id,
    required this.keyword,
    required this.categoryId,
    this.priority = 1,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, keyword, categoryId, priority, isActive];

  factory AssignmentRule.fromMap(Map<String, dynamic> map, String id) {
    return AssignmentRule(
      id: id,
      keyword: map['keyword'] ?? map['pattern'] ?? '', // Fallback for old data if any
      categoryId: map['categoryId'] ?? map['targetCategoryId'] ?? '',
      priority: map['priority'] ?? 1,
      isActive: map['isActive'] ?? true,
    );
  }

  // Helper for Firestore where ID is separate
  factory AssignmentRule.fromJson(Map<String, dynamic> json) {
      // If ID is part of json or needs to be injected. 
      // FirestoreService injects ID into the map usually or passes it.
      // But here we might receive it embedded.
      // Assuming 'id' is in map if coming from ConfigProvider's internal logic, 
      // but from FirestoreService it comes from doc.id. 
      // Let's rely on fromMap mostly, but fromJson is expected by some previous code?
      // No, ConfigProvider uses .listening((rules)...).
      return AssignmentRule.fromMap(json, json['id'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'keyword': keyword,
      'categoryId': categoryId,
      'priority': priority,
      'isActive': isActive,
    };
  }

  // Alias for compatibility if needed
  Map<String, dynamic> toJson() => toMap();
}
