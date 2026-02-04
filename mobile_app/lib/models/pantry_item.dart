class PantryItem {
  final String id;
  final String name;
  final String quantity;
  final DateTime? expiryDate;
  final String category;
  final String? imageUrl;

  PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.expiryDate,
    this.category = 'Other',
    this.imageUrl,
  });

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  String get expiryStatus {
    if (expiryDate == null) return 'No expiry date';
    if (isExpired) return 'Expired';
    if (isExpiringSoon) return 'Expiring soon';
    return 'Fresh';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'expiryDate': expiryDate?.toIso8601String(),
      'category': category,
      'imageUrl': imageUrl,
    };
  }

  factory PantryItem.fromMap(Map<String, dynamic> map) {
    return PantryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: map['quantity'] as String,
      expiryDate: map['expiryDate'] != null 
          ? DateTime.parse(map['expiryDate'] as String)
          : null,
      category: map['category'] as String? ?? 'Other',
      imageUrl: map['imageUrl'] as String?,
    );
  }

  /// Try to extract an integer quantity from the `quantity` string.
  /// Returns null when no numeric value can be parsed.
  int? quantityAsInt() {
    final regex = RegExp(r"(\\d+)");
    final match = regex.firstMatch(quantity);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Simple low-stock checker. If `threshold` is null, uses 1.
  /// Parses numeric part of `quantity` when possible; otherwise, treats common keywords.
  bool isLowStock({int threshold = 1}) {
    final q = quantityAsInt();
    if (q != null) return q <= threshold;
    final val = quantity.toLowerCase();
    if (val.contains('low') || val.contains('few') || val.contains('half') || val.contains('almost')) return true;
    if (val.contains('none') || val.contains('empty') || val.contains('0')) return true;
    return false;
  }
}