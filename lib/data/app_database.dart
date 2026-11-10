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
      version: 3,
      onCreate: (db, version) async {
        await _createUsers(db);
        await _createDpEntries(db);
        await _createBonusEntries(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createDpEntries(db);
        if (oldVersion < 3) await _createBonusEntries(db);
      },
    );
    return _db!;
  }

  Future<void> _createUsers(DatabaseExecutor db) async {
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
  }

  Future<void> _createDpEntries(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE dp_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        dp1 REAL NOT NULL DEFAULT 0,
        dp2 REAL NOT NULL DEFAULT 0,
        dp3 REAL NOT NULL DEFAULT 0,
        dp4 REAL NOT NULL DEFAULT 0,
        dp5 REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL,
        dp_count INTEGER NOT NULL,
        contacted INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_dp_date ON dp_entries(entry_date)');
    await db.execute('CREATE INDEX idx_dp_user ON dp_entries(user_id)');
  }

  Future<void> _createBonusEntries(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE bonus_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        related_dp REAL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_bonus_date ON bonus_entries(entry_date)');
    await db.execute('CREATE INDEX idx_bonus_user ON bonus_entries(user_id)');
  }

  Future<double> monthBonusTotal() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month).toIso8601String().substring(0, 10);
    final end = DateTime(now.year, now.month + 1).toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM bonus_entries WHERE entry_date >= ? AND entry_date < ?',
      [start, end],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<List<Map<String, Object?>>> getBonusEntries() async {
    final db = await database;
    return db.rawQuery('''
      SELECT b.*, u.name AS user_name
      FROM bonus_entries b JOIN users u ON u.id = b.user_id
      ORDER BY b.entry_date DESC, b.id DESC
    ''');
  }

  Future<int> addBonusEntry({
    required int userId,
    required DateTime date,
    required double amount,
    required String reason,
    double? relatedDp,
    String notes = '',
  }) async {
    if (amount <= 0) throw ArgumentError('Bonus amount must be greater than zero');
    final db = await database;
    return db.insert('bonus_entries', {
      'user_id': userId,
      'entry_date': date.toIso8601String().substring(0, 10),
      'amount': amount,
      'reason': reason,
      'related_dp': relatedDp,
      'notes': notes.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
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

  Future<double> monthDpTotal() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month).toIso8601String().substring(0, 10);
    final end = DateTime(now.year, now.month + 1).toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS total FROM dp_entries WHERE entry_date >= ? AND entry_date < ?',
      [start, end],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<List<Map<String, Object?>>> getDpEntries() async {
    final db = await database;
    return db.rawQuery('''
      SELECT d.*, u.name AS user_name, u.phone AS user_phone
      FROM dp_entries d JOIN users u ON u.id = d.user_id
      ORDER BY d.entry_date DESC, d.id DESC
    ''');
  }

  Future<int> addDpEntry({
    required int userId,
    required DateTime date,
    required List<double> amounts,
    bool contacted = false,
    String notes = '',
  }) async {
    final values = List<double>.generate(5, (i) => i < amounts.length ? amounts[i] : 0);
    final count = values.where((v) => v > 0).length;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (count == 0) throw ArgumentError('Enter at least one DP amount');
    final db = await database;
    return db.insert('dp_entries', {
      'user_id': userId,
      'entry_date': date.toIso8601String().substring(0, 10),
      'dp1': values[0], 'dp2': values[1], 'dp3': values[2],
      'dp4': values[3], 'dp5': values[4],
      'total': total, 'dp_count': count, 'contacted': contacted ? 1 : 0,
      'notes': notes.trim(), 'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> addUser({required String name, required String phone, String notes = ''}) async {
    final db = await database;
    return db.insert('users', {
      'name': name.trim(), 'phone': phone.trim(), 'notes': notes.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateUser({required int id, required String name, required String phone, String notes = ''}) async {
    final db = await database;
    return db.update('users', {'name': name.trim(), 'phone': phone.trim(), 'notes': notes.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> archiveUser(int id) async {
    final db = await database;
    return db.update('users', {'archived': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
