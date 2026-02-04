import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/pantry_item.dart';

class PantryService {
  static final PantryService instance = PantryService._init();

  static Database? _database;

  PantryService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pantry.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    Directory docDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docDir.path, fileName);
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDB,
    );
  }

  FutureOr<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pantry_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        quantity TEXT NOT NULL,
        expiryDate TEXT,
        category TEXT,
        imageUrl TEXT
      )
    ''');
  }

  Future<List<PantryItem>> getAllItems() async {
    final db = await database;
    final rows = await db.query('pantry_items', orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => PantryItem.fromMap(r)).toList();
  }

  Future<void> insertItem(PantryItem item) async {
    final db = await database;
    await db.insert('pantry_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateItem(PantryItem item) async {
    final db = await database;
    await db.update('pantry_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('pantry_items');
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
