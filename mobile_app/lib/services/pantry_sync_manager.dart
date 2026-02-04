import 'dart:async';

import '../models/pantry_item.dart';
import 'pantry_service.dart';
import 'pantry_firebase_service.dart';

class PantrySyncManager {
  PantrySyncManager._();
  static final PantrySyncManager instance = PantrySyncManager._();

  final PantryService _local = PantryService.instance;
  final PantryFirebaseService _cloud = PantryFirebaseService.instance;

  StreamSubscription? _cloudSub;
  final StreamController<List<PantryItem>> _localController = StreamController.broadcast();

  Stream<List<PantryItem>> get localStream => _localController.stream;

  /// Start two-way sync: load local items and subscribe to cloud changes.
  Future<void> start() async {
    final local = await _local.getAllItems();
    _localController.add(local);

    _cloudSub ??= _cloud.itemsStream().listen((cloudItems) async {
      // Merge cloud items into local DB (cloud wins on conflict)
      for (final item in cloudItems) {
        final existing = (await _local.getAllItems()).where((i) => i.id == item.id);
        if (existing.isEmpty) {
          await _local.insertItem(item);
        } else {
          await _local.updateItem(item);
        }
      }
      final merged = await _local.getAllItems();
      _localController.add(merged);
    });
  }

  Future<void> stop() async {
    await _cloudSub?.cancel();
    _cloudSub = null;
    await _localController.close();
  }

  /// Push current local items to cloud (merge by id)
  Future<void> pushLocalToCloud() async {
    final local = await _local.getAllItems();
    await _cloud.pushAll(local);
  }

  /// Pull cloud items and return them (does not modify local)
  Future<List<PantryItem>> pullCloud() => _cloud.getAllItems();

  /// Convenience: add locally and push to cloud.
  Future<void> addItem(PantryItem item, {bool push = true}) async {
    await _local.insertItem(item);
    if (push) await _cloud.uploadItem(item);
    _localController.add(await _local.getAllItems());
  }

  Future<void> deleteItem(String id, {bool remote = true}) async {
    await _local.deleteItem(id);
    if (remote) await _cloud.deleteItem(id);
    _localController.add(await _local.getAllItems());
  }

  Future<void> updateItem(PantryItem item, {bool push = true}) async {
    await _local.updateItem(item);
    if (push) await _cloud.uploadItem(item);
    _localController.add(await _local.getAllItems());
  }
}
