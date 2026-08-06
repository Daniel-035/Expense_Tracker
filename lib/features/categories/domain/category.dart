import 'package:equatable/equatable.dart';

enum CategoryType { income, expense }

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final CategoryType type;
  final int color;
  final String icon;
  final bool isSystem;

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'color': color,
        'icon': icon,
        'isSystem': isSystem,
      };

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'expense';
    return Category(
      id: id,
      name: map['name'] as String? ?? '',
      type: typeStr == 'income' ? CategoryType.income : CategoryType.expense,
      color: map['color'] as int? ?? 0xFF607D8B,
      icon: map['icon'] as String? ?? 'category',
      isSystem: map['isSystem'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, name, type, color, icon, isSystem];
}
