import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'user_hub.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL UNIQUE,
            notes TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<Map<String, Object?>>> getUsers({String search = ''}) async {
    final db = await database;
    if (search.trim().isEmpty) {
      return db.query('users', where: 'archived = 0', orderBy: 'name COLLATE NOCASE');
    }
    return db.query(
      'users',
      where: 'archived = 0 AND (name LIKE ? OR phone LIKE ?)',
      whereArgs: ['%$search%', '%$search%'],
      orderBy: 'name COLLATE NOCASE',
    );
  }

  Future<int> countUsers() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM users WHERE archived = 0');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> addUser({required String name, required String phone, String notes = ''}) async {
    final db = await database;
    return db.insert('users', {
      'name': name.trim(),
      'phone': phone.trim(),
      'notes': notes.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateUser({required int id, required String name, required String phone, String notes = ''}) async {
    final db = await database;
    return db.update(
      'users',
      {'name': name.trim(), 'phone': phone.trim(), 'notes': notes.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> archiveUser(int id) async {
    final db = await database;
    return db.update('users', {'archived': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
