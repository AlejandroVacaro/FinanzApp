import 'package:equatable/equatable.dart';

enum CategoryType { income, expense, transfer, savings }

class Category extends Equatable {
  final String id;
  final String name;
  final String icon; // Identificador del icono (ej: 'food_bank')
  final String color; // Hex string (ej: '#FF5733')
  final CategoryType type;
  final String? parentId; // Para subcategorías

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.parentId,
  });

  @override
  List<Object?> get props => [id, name, icon, color, type, parentId];

  // Factory simple para iniciar desde Firestore map
  factory Category.fromMap(Map<String, dynamic> map, String id) {
    return Category(
      id: id,
      name: map['name'] ?? '',
      icon: map['icon'] ?? 'help_outline',
      color: map['color'] ?? '#808080',
      type: CategoryType.values.firstWhere(
        (e) => e.toString() == 'CategoryType.${map['type']}' || e.name == map['type'],
        orElse: () => CategoryType.expense,
      ),
      parentId: map['parentId'],
    );
  }

  // Helper alias for generic consistency
  factory Category.fromJson(Map<String, dynamic> json) {
       // Assuming ID is passed inside if strict json or using fallback
       return Category.fromMap(json, json['id'] ?? '');
  }
  
  // Helper alias
  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'color': color,
      'type': type.name, // 'income', 'expense', etc.
      'parentId': parentId,
    };
  }
}
