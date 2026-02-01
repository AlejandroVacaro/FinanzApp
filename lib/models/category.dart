import 'package:equatable/equatable.dart';

enum CategoryType { income, expense }

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
        (e) => e.toString() == 'CategoryType.${map['type']}',
        orElse: () => CategoryType.expense,
      ),
      parentId: map['parentId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'color': color,
      'type': type.name, // 'income' o 'expense'
      'parentId': parentId,
    };
  }
}
