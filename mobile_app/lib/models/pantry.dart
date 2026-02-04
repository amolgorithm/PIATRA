import 'pantry_item.dart';

class Pantry {
  final List<PantryItem> items;

  Pantry({List<PantryItem>? items}) : items = items ?? [];

  void addItem(PantryItem item) => items.add(item);

  void removeById(String id) => items.removeWhere((i) => i.id == id);

  void updateItem(PantryItem item) {
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx != -1) items[idx] = item;
  }

  PantryItem? getById(String id) {
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory Pantry.fromMap(Map<String, dynamic> map) {
    final list = <PantryItem>[];
    if (map['items'] is List) {
      for (final dynamic m in map['items'] as List) {
        if (m is Map<String, dynamic>) list.add(PantryItem.fromMap(m));
      }
    }
    return Pantry(items: list);
  }
}
