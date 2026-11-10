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
      version: 5,
      onCreate: (db, version) async {
        await _createUsers(db);
        await _createDpEntries(db);
        await _createBonusEntries(db);
        await _createPotentialUsers(db);
        await _createContactHistory(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createDpEntries(db);
        if (oldVersion < 3) await _createBonusEntries(db);
        if (oldVersion < 4) await _createPotentialUsers(db);
        if (oldVersion < 5) await _createContactHistory(db);
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
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

  Future<void> _createPotentialUsers(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE potential_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL UNIQUE,
        source TEXT NOT NULL DEFAULT '',
        language TEXT NOT NULL DEFAULT '',
        sports TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'New Lead',
        follow_up_date TEXT,
        contact_permission INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_potential_status ON potential_users(status)');
  }

  Future<void> _createContactHistory(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE contact_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        contact_date TEXT NOT NULL,
        channel TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        outcome TEXT NOT NULL,
        response TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        follow_up_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_contact_date ON contact_history(contact_date)');
    await db.execute('CREATE INDEX idx_contact_user ON contact_history(user_id)');
    await db.execute('CREATE INDEX idx_contact_followup ON contact_history(follow_up_date)');
  }

  Future<List<Map<String, Object?>>> getContactHistory({String search = ''}) async {
    final db = await database;
    final term = search.trim();
    return db.rawQuery('''
      SELECT c.*, u.name AS user_name, u.phone AS user_phone
      FROM contact_history c
      JOIN users u ON u.id = c.user_id
      WHERE (? = '' OR u.name LIKE ? OR u.phone LIKE ? OR c.reason LIKE ? OR c.notes LIKE ?)
      ORDER BY c.contact_date DESC, c.id DESC
    ''', [term, '%$term%', '%$term%', '%$term%', '%$term%']);
  }

  Future<int> addContactLog({
    required int userId,
    required DateTime contactDate,
    required String channel,
    required String reason,
    required String outcome,
    String response = '',
    String notes = '',
    DateTime? followUpDate,
  }) async {
    final db = await database;
    return db.insert('contact_history', {
      'user_id': userId,
      'contact_date': contactDate.toIso8601String(),
      'channel': channel,
      'reason': reason.trim(),
      'outcome': outcome,
      'response': response.trim(),
      'notes': notes.trim(),
      'follow_up_date': followUpDate?.toIso8601String().substring(0, 10),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> countFollowUpsDue() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM contact_history WHERE follow_up_date IS NOT NULL AND follow_up_date <= ?",
      [today],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> countPotentialUsers() async {
    final db = await database;
    final rows = await db.rawQuery("SELECT COUNT(*) AS total FROM potential_users WHERE status != 'Registered' AND status != 'Do Not Contact'");
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<Map<String, Object?>>> getPotentialUsers({String search = ''}) async {
    final db = await database;
    final term = search.trim();
    return db.query('potential_users',
      where: "status != 'Registered' AND (? = '' OR name LIKE ? OR phone LIKE ?)",
      whereArgs: [term, '%$term%', '%$term%'],
      orderBy: 'created_at DESC');
  }

  Future<int> addPotentialUser({
    required String name, required String phone, String source = '',
    String language = '', String sports = '', String notes = '',
    String status = 'New Lead', DateTime? followUpDate, bool contactPermission = false,
  }) async {
    final db = await database;
    return db.insert('potential_users', {
      'name': name.trim(), 'phone': phone.trim(), 'source': source.trim(),
      'language': language.trim(), 'sports': sports.trim(), 'notes': notes.trim(),
      'status': status,
      'follow_up_date': followUpDate?.toIso8601String().substring(0, 10),
      'contact_permission': contactPermission ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updatePotentialStatus(int id, String status) async {
    final db = await database;
    return db.update('potential_users', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> convertPotentialUser(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query('potential_users', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('Potential user not found');
      final prospect = rows.first;
      final existing = await txn.query('users', columns: ['id'], where: 'phone = ?', whereArgs: [prospect['phone']], limit: 1);
      if (existing.isNotEmpty) throw StateError('This phone number is already registered');
      await txn.insert('users', {
        'name': prospect['name'], 'phone': prospect['phone'],
        'notes': prospect['notes'], 'created_at': DateTime.now().toIso8601String(),
      });
      return txn.update('potential_users', {'status': 'Registered'}, where: 'id = ?', whereArgs: [id]);
    });
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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month).toIso8601String().substring(0, 10);
    final end = DateTime(now.year, now.month + 1).toIso8601String().substring(0, 10);
    final term = search.trim();
    return db.rawQuery('''
      SELECT u.*,
        COALESCE((SELECT SUM(d.total) FROM dp_entries d WHERE d.user_id = u.id), 0) AS lifetime_dp,
        COALESCE((SELECT SUM(d.total) FROM dp_entries d WHERE d.user_id = u.id AND d.entry_date >= ? AND d.entry_date < ?), 0) AS monthly_dp
      FROM users u
      WHERE u.archived = 0 AND (? = '' OR u.name LIKE ? OR u.phone LIKE ?)
      ORDER BY u.name COLLATE NOCASE
    ''', [start, end, term, '%$term%', '%$term%']);
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


  Future<Map<String, double>> dashboardTotals() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month).toIso8601String().substring(0, 10);
    final end = DateTime(now.year, now.month + 1).toIso8601String().substring(0, 10);
    final dp = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS total FROM dp_entries WHERE entry_date >= ? AND entry_date < ?',
      [start, end],
    );
    final bonus = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM bonus_entries WHERE entry_date >= ? AND entry_date < ?',
      [start, end],
    );
    return {
      'dp': (dp.first['total'] as num).toDouble(),
      'bonus': (bonus.first['total'] as num).toDouble(),
    };
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
