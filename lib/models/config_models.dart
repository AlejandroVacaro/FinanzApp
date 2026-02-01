enum CategoryType { income, expense, transfer, savings }

class Category {
  final String id;
  String name;
  CategoryType type;

  Category({required this.id, required this.name, required this.type});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last, // Store as string "income", "expense"
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      type: CategoryType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => CategoryType.expense,
      ),
    );
  }
}

class AssignmentRule {
  final String id;
  String keyword;
  String categoryId;

  AssignmentRule({required this.id, required this.keyword, required this.categoryId});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyword': keyword,
      'categoryId': categoryId,
    };
  }

  factory AssignmentRule.fromJson(Map<String, dynamic> json) {
    return AssignmentRule(
      id: json['id'],
      keyword: json['keyword'],
      categoryId: json['categoryId'],
    );
  }
}
