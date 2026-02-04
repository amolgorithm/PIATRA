import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pantry_item.dart';

class PantryFirebaseService {
  PantryFirebaseService._();
  static final PantryFirebaseService instance = PantryFirebaseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('pantry_items');

  Future<void> uploadItem(PantryItem item) async {
    final data = <String, dynamic>{
      'name': item.name,
      'quantity': item.quantity,
      'expiryDate': item.expiryDate != null ? Timestamp.fromDate(item.expiryDate!) : null,
      'category': item.category,
      'imageUrl': item.imageUrl,
      'id': item.id,
    };
    await _col.doc(item.id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteItem(String id) async {
    await _col.doc(id).delete();
  }

  Future<List<PantryItem>> getAllItems() async {
    final snap = await _col.get();
    return snap.docs.map((d) => _docToItem(d)).toList();
  }

  Stream<List<PantryItem>> itemsStream() {
    return _col.snapshots().map((snap) => snap.docs.map(_docToItem).toList());
  }

  PantryItem _docToItem(QueryDocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>;
    DateTime? expiry;
    final ed = data['expiryDate'];
    if (ed != null) {
      if (ed is Timestamp) expiry = ed.toDate();
      else if (ed is String) expiry = DateTime.tryParse(ed);
    }
    return PantryItem(
      id: d.id,
      name: data['name'] as String? ?? '',
      quantity: data['quantity'] as String? ?? '',
      expiryDate: expiry,
      category: data['category'] as String? ?? 'Other',
      imageUrl: data['imageUrl'] as String?,
    );
  }

  /// Simple push of all local items to cloud (overwrites / merges by id).
  Future<void> pushAll(List<PantryItem> localItems) async {
    final batch = _firestore.batch();
    for (final item in localItems) {
      final docRef = _col.doc(item.id);
      final data = <String, dynamic>{
        'name': item.name,
        'quantity': item.quantity,
        'expiryDate': item.expiryDate != null ? Timestamp.fromDate(item.expiryDate!) : null,
        'category': item.category,
        'imageUrl': item.imageUrl,
        'id': item.id,
      };
      batch.set(docRef, data, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Pull cloud items and return them for local merge.
  Future<List<PantryItem>> pullAll() async => getAllItems();
}
