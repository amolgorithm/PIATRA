class Nutrition {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;
  final double? sugar;

  Nutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.sugar,
  });

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
    };
  }

  factory Nutrition.fromMap(Map<String, dynamic> map) {
    return Nutrition(
      calories: map['calories'] as int,
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      fiber: map['fiber'] != null ? (map['fiber'] as num).toDouble() : null,
      sugar: map['sugar'] != null ? (map['sugar'] as num).toDouble() : null,
    );
  }
}