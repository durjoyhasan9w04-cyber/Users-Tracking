import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../models/user_level_config.dart';

const int supportedUserHubDatabaseVersion = 15;

Set<String> requiredBackupTablesForVersion(int version) {
  if (version < 1 || version > supportedUserHubDatabaseVersion) {
    throw ArgumentError('Unsupported User Hub database version: $version');
  }
  return <String>{
    'users',
    if (version >= 2) 'dp_entries',
    if (version >= 3) 'bonus_entries',
    if (version >= 4) 'potential_users',
    if (version >= 5) 'contact_history',
    if (version >= 6) 'customer_issues',
    if (version >= 8) 'audit_log',
    if (version >= 9) 'sports_interests',
    if (version >= 9) 'matches',
    if (version >= 12) 'user_level_settings',
    if (version >= 14) 'contact_reminders',
    if (version >= 15) 'potential_contact_history',
  };
}

List<double> validateDpAmounts(List<double> amounts) {
  if (amounts.length > 5) {
    throw ArgumentError('A daily DP entry can contain at most five amounts');
  }
  if (amounts.any((value) => !value.isFinite || value < 0)) {
    throw ArgumentError('DP amounts must be finite and cannot be negative');
  }
  final values = List<double>.generate(5, (i) => i < amounts.length ? amounts[i] : 0);
  if (!values.any((value) => value > 0)) {
    throw ArgumentError('Enter at least one DP amount');
  }
  return values;
}

void validateBonusAmounts(double amount, double? relatedDp) {
  if (!amount.isFinite || amount <= 0) {
    throw ArgumentError('Bonus amount must be a finite value greater than zero');
  }
  if (relatedDp != null && (!relatedDp.isFinite || relatedDp < 0)) {
    throw ArgumentError('Related DP must be finite and cannot be negative');
  }
}

class DuplicatePhoneException implements Exception {
  const DuplicatePhoneException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'user_hub.db'),
      version: supportedUserHubDatabaseVersion,
      onCreate: (db, version) async {
        await _createUsers(db);
        await _createDpEntries(db);
        await _createBonusEntries(db);
        await _createPotentialUsers(db);
        await _createContactHistory(db);
        await _createContactReminders(db);
        await _createPotentialContactHistory(db);
        await _createCustomerIssues(db);
        await _createAuditLog(db);
        await _createSportsTables(db);
        await _createUserLevelSettings(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createDpEntries(db);
        if (oldVersion < 3) await _createBonusEntries(db);
        if (oldVersion < 4) await _createPotentialUsers(db);
        if (oldVersion < 5) await _createContactHistory(db);
        if (oldVersion < 6) await _createCustomerIssues(db);
        if (oldVersion >= 5 && oldVersion < 7) await db.execute("ALTER TABLE contact_history ADD COLUMN follow_up_completed INTEGER NOT NULL DEFAULT 0");
        if (oldVersion < 8) await _createAuditLog(db);
        if (oldVersion < 9) await _createSportsTables(db);
        if (oldVersion < 10) await db.execute('ALTER TABLE users ADD COLUMN do_not_contact INTEGER NOT NULL DEFAULT 0');
        if (oldVersion < 11) {
          await db.execute("ALTER TABLE users ADD COLUMN preferred_language TEXT NOT NULL DEFAULT ''");
          await db.execute("ALTER TABLE users ADD COLUMN preferred_contact_method TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 12) await _createUserLevelSettings(db);
        if (oldVersion < 13) await db.execute("ALTER TABLE users ADD COLUMN previous_dp_at TEXT");
        if (oldVersion < 14) await _createContactReminders(db);
        if (oldVersion < 15) await _createPotentialContactHistory(db);
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  Future<void> createDailyBackupIfNeeded() async {
    final liveDb = await database;
    await liveDb.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final support = await getApplicationSupportDirectory();
    final folder = Directory(p.join(support.path, 'backups'));
    await folder.create(recursive: true);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final backup = File(p.join(folder.path, 'user-hub-$today.db'));
    final root = await getDatabasesPath();
    final source = File(p.join(root, 'user_hub.db'));
    if (!await backup.exists() && await source.exists()) {
      await source.copy(backup.path);
    }
    final files = folder.listSync().whereType<File>()
      .where((file) => p.basename(file.path).startsWith('user-hub-') && file.path.endsWith('.db'))
      .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in files.skip(7)) {
      await old.delete();
    }
  }

  Future<String> createBackupFile() async {
    final liveDb = await database;
    await liveDb.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final root = await getDatabasesPath();
    final source = File(p.join(root, 'user_hub.db'));
    if (!await source.exists()) throw StateError('Database file not found');
    final temp = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final backup = File(p.join(temp.path, 'user-hub-backup-$stamp.db'));
    await source.copy(backup.path);
    return backup.path;
  }

  Future<bool> checkIntegrity() async {
    final db = await database;
    final rows = await db.rawQuery('PRAGMA integrity_check');
    return rows.isNotEmpty && rows.first.values.first == 'ok';
  }

  Future<void> restoreBackupFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw ArgumentError('Backup file does not exist');
    }

    // Validate the backup before touching the currently installed database.
    final candidate = await openDatabase(source.path, readOnly: true);
    try {
      final integrity = await candidate.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw StateError('The selected backup failed its integrity check');
      }

      final versionRows = await candidate.rawQuery('PRAGMA user_version');
      final backupVersion = (versionRows.first.values.first as num).toInt();
      final required = requiredBackupTablesForVersion(backupVersion);
      final tables = await candidate.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name'] as String).toSet();
      if (!names.containsAll(required)) {
        throw StateError('This file is not a compatible User Hub backup.');
      }
    } finally {
      await candidate.close();
    }

    final root = await getDatabasesPath();
    final destination = File(p.join(root, 'user_hub.db'));
    final temp = await getTemporaryDirectory();
    final rollback = File(p.join(temp.path, 'user-hub-before-restore.db'));
    final hadExistingDatabase = await destination.exists();

    // Flush WAL pages and close SQLite before copying the database file so
    // the rollback copy contains a consistent, self-contained snapshot.
    if (_db != null) {
      await _db!.rawQuery('PRAGMA wal_checkpoint(FULL)');
      await _db!.close();
      _db = null;
    }
    if (hadExistingDatabase) {
      await destination.copy(rollback.path);
    }

    try {
      await source.copy(destination.path);
      await database; // Runs any required migrations for older backups.
      final valid = await checkIntegrity();
      if (!valid) {
        throw StateError('Restored database failed its integrity check');
      }
    } catch (_) {
      await _db?.close();
      _db = null;
      if (hadExistingDatabase && await rollback.exists()) {
        await rollback.copy(destination.path);
        await database;
      } else {
        if (await destination.exists()) await destination.delete();
      }
      rethrow;
    } finally {
      if (await rollback.exists()) await rollback.delete();
    }
  }

  Future<void> _createUserLevelSettings(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE user_level_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        settings_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.insert('user_level_settings', {
      'id': 1,
      'settings_json': jsonEncode(UserLevelConfig.defaults.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<UserLevelConfig> getUserLevelConfig() async {
    final db = await database;
    final rows = await db.query('user_level_settings', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return UserLevelConfig.defaults;
    try {
      return UserLevelConfig.fromJson(
        jsonDecode(rows.first['settings_json'] as String) as Map<String, dynamic>,
      );
    } catch (_) {
      return UserLevelConfig.defaults;
    }
  }

  Future<void> saveUserLevelConfig(UserLevelConfig config) async {
    config.validate();
    final db = await database;
    await db.insert('user_level_settings', {
      'id': 1,
      'settings_json': jsonEncode(config.toJson()),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _createUsers(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL UNIQUE,
        notes TEXT NOT NULL DEFAULT '',
        do_not_contact INTEGER NOT NULL DEFAULT 0,
        preferred_language TEXT NOT NULL DEFAULT '',
        preferred_contact_method TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0,
        previous_dp_at TEXT
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

  Future<void> _createContactReminders(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE contact_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        remind_at TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_contact_reminders_user ON contact_reminders(user_id)');
    await db.execute('CREATE INDEX idx_contact_reminders_due ON contact_reminders(completed, remind_at)');
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
        follow_up_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_contact_date ON contact_history(contact_date)');
    await db.execute('CREATE INDEX idx_contact_user ON contact_history(user_id)');
    await db.execute('CREATE INDEX idx_contact_followup ON contact_history(follow_up_date)');
  }

  Future<void> _createPotentialContactHistory(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE potential_contact_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        potential_user_id INTEGER NOT NULL,
        contact_at TEXT NOT NULL,
        channel TEXT NOT NULL,
        discussion TEXT NOT NULL DEFAULT '',
        outcome TEXT NOT NULL DEFAULT 'Follow-up needed',
        follow_up_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(potential_user_id) REFERENCES potential_users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_potential_contact_user ON potential_contact_history(potential_user_id, contact_at)');
    await db.execute('CREATE INDEX idx_potential_contact_followup ON potential_contact_history(follow_up_at)');
  }

  Future<void> _createCustomerIssues(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE customer_issues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        title TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'General',
        description TEXT NOT NULL DEFAULT '',
        priority TEXT NOT NULL DEFAULT 'Normal',
        status TEXT NOT NULL DEFAULT 'Open',
        resolution TEXT NOT NULL DEFAULT '',
        opened_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        resolved_at TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_issue_status ON customer_issues(status)');
    await db.execute('CREATE INDEX idx_issue_user ON customer_issues(user_id)');
    await db.execute('CREATE INDEX idx_issue_priority ON customer_issues(priority)');
  }

  Future<List<Map<String, Object?>>> getCustomerIssues({String search = '', String status = 'All'}) async {
    final db = await database;
    final term = search.trim();
    return db.rawQuery('''
      SELECT i.*, u.name AS user_name, u.phone AS user_phone
      FROM customer_issues i LEFT JOIN users u ON u.id = i.user_id
      WHERE (? = '' OR i.title LIKE ? OR i.description LIKE ? OR i.category LIKE ? OR COALESCE(u.name, '') LIKE ? OR COALESCE(u.phone, '') LIKE ?)
        AND (? = 'All' OR i.status = ?)
      ORDER BY CASE i.status WHEN 'Open' THEN 0 WHEN 'In Progress' THEN 1 WHEN 'Waiting for Customer' THEN 2 WHEN 'Resolved' THEN 3 ELSE 4 END,
        CASE i.priority WHEN 'Urgent' THEN 0 WHEN 'High' THEN 1 WHEN 'Normal' THEN 2 ELSE 3 END,
        i.updated_at DESC
    ''', [term, '%$term%', '%$term%', '%$term%', '%$term%', '%$term%', status, status]);
  }

  Future<int> addCustomerIssue({
    int? userId, required String title, required String category,
    required String description, required String priority,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('customer_issues', {
      'user_id': userId, 'title': title.trim(), 'category': category,
      'description': description.trim(), 'priority': priority,
      'status': 'Open', 'opened_at': now, 'updated_at': now,
    });
  }

  Future<int> updateCustomerIssue({
    required int id, required String status, required String priority,
    required String resolution,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.update('customer_issues', {
      'status': status, 'priority': priority,
      'resolution': resolution.trim(), 'updated_at': now,
      'resolved_at': status == 'Resolved' || status == 'Closed' ? now : null,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countOpenCustomerIssues() async {
    final db = await database;
    final rows = await db.rawQuery("SELECT COUNT(*) AS total FROM customer_issues WHERE status IN ('Open', 'In Progress', 'Waiting for Customer')");
    return Sqflite.firstIntValue(rows) ?? 0;
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

  Future<int> addContactReminder({
    required int userId,
    required DateTime remindAt,
    String reason = '',
  }) async {
    final db = await database;
    if (!remindAt.isAfter(DateTime.now())) {
      throw ArgumentError('Choose a reminder time in the future.');
    }
    return db.insert('contact_reminders', {
      'user_id': userId,
      'remind_at': remindAt.toIso8601String(),
      'reason': reason.trim(),
      'completed': 0,
      'created_at': DateTime.now().toIso8601String(),
      'completed_at': null,
    });
  }

  Future<List<Map<String, Object?>>> getContactReminders({int? userId, bool includeCompleted = false}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];
    if (userId != null) { where.add('r.user_id = ?'); args.add(userId); }
    if (!includeCompleted) where.add('r.completed = 0');
    return db.rawQuery('''
      SELECT r.*, u.name AS user_name, u.phone AS user_phone
      FROM contact_reminders r JOIN users u ON u.id = r.user_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY r.remind_at ASC, r.id ASC
    ''', args);
  }

  Future<List<Map<String, Object?>>> getDueContactReminders() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT r.id, r.user_id, r.remind_at AS due_at, r.reason,
        u.name AS user_name, u.phone AS user_phone
      FROM contact_reminders r JOIN users u ON u.id = r.user_id
      WHERE r.completed = 0 AND substr(r.remind_at, 1, 10) <= ? AND u.archived = 0
      ORDER BY r.remind_at ASC, u.name COLLATE NOCASE
    ''', [today]);
  }

  Future<int> deleteContactReminder(int id) async {
    final db = await database;
    return db.delete('contact_reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> completeContactReminder(int id) async {
    final db = await database;
    return db.update('contact_reminders', {
      'completed': 1,
      'completed_at': DateTime.now().toIso8601String(),
    }, where: 'id = ? AND completed = 0', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> getUsualDpTimePatterns() async {
    final db = await database;
    return db.rawQuery("""
      SELECT u.id AS user_id, u.name AS user_name, COUNT(d.id) AS record_count,
        AVG(CAST(strftime('%H', d.created_at) AS INTEGER) * 60 +
            CAST(strftime('%M', d.created_at) AS INTEGER)) AS usual_minute
      FROM users u
      JOIN dp_entries d ON d.user_id = u.id
      WHERE u.archived = 0 AND u.do_not_contact = 0
        AND datetime(substr(d.created_at, 1, 19)) >= datetime('now', 'localtime', '-30 days')
      GROUP BY u.id
      HAVING COUNT(d.id) >= 3
      ORDER BY usual_minute ASC, u.name COLLATE NOCASE
    """);
  }

  Future<List<Map<String, Object?>>> getDueContactFollowUps() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.rawQuery("""
      SELECT c.id, c.user_id, c.follow_up_date AS due_date, c.reason, c.notes,
        u.name AS user_name, u.phone AS user_phone
      FROM contact_history c JOIN users u ON u.id = c.user_id
      WHERE c.follow_up_date IS NOT NULL AND c.follow_up_date <= ?
        AND c.follow_up_completed = 0 AND u.archived = 0 AND u.do_not_contact = 0
      ORDER BY c.follow_up_date ASC, u.name COLLATE NOCASE
    """, [today]);
  }

  Future<List<Map<String, Object?>>> getDuePotentialFollowUps() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.query('potential_users',
      columns: ['id', 'name', 'phone', 'follow_up_date', 'status'],
      where: "follow_up_date IS NOT NULL AND follow_up_date <= ? AND contact_permission = 1 AND status NOT IN ('Registered', 'Do Not Contact', 'Not Interested')",
      whereArgs: [today],
      orderBy: 'follow_up_date ASC, name COLLATE NOCASE');
  }

  Future<int> completeContactFollowUp(int id) async {
    final db = await database;
    return db.update('contact_history', {'follow_up_completed': 1},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<int> completePotentialFollowUp(int id) async {
    final db = await database;
    return db.update('potential_users', {'follow_up_date': null},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countFollowUpsDue() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final contacts = await db.rawQuery(
      """SELECT COUNT(*) AS total FROM contact_history c
         JOIN users u ON u.id = c.user_id
         WHERE c.follow_up_date IS NOT NULL AND c.follow_up_date <= ?
           AND c.follow_up_completed = 0 AND u.archived = 0 AND u.do_not_contact = 0""",
      [today],
    );
    final prospects = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM potential_users WHERE follow_up_date IS NOT NULL AND follow_up_date <= ? AND contact_permission = 1 AND status NOT IN ('Registered', 'Do Not Contact', 'Not Interested')",
      [today],
    );
    final reminders = await db.rawQuery(
      """SELECT COUNT(*) AS total FROM contact_reminders r
         JOIN users u ON u.id = r.user_id
         WHERE r.completed = 0 AND substr(r.remind_at, 1, 10) <= ? AND u.archived = 0""",
      [today],
    );
    return (Sqflite.firstIntValue(contacts) ?? 0) +
        (Sqflite.firstIntValue(prospects) ?? 0) +
        (Sqflite.firstIntValue(reminders) ?? 0);
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

  Future<int> addPotentialContact({
    required int potentialUserId,
    required DateTime contactAt,
    required String channel,
    required String discussion,
    required String outcome,
    DateTime? followUpAt,
  }) async {
    final db = await database;
    return db.insert('potential_contact_history', {
      'potential_user_id': potentialUserId,
      'contact_at': contactAt.toIso8601String(),
      'channel': channel.trim(),
      'discussion': discussion.trim(),
      'outcome': outcome,
      'follow_up_at': followUpAt?.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getPotentialContactHistory(int potentialUserId) async {
    final db = await database;
    return db.query('potential_contact_history',
      where: 'potential_user_id = ?', whereArgs: [potentialUserId],
      orderBy: 'contact_at DESC, id DESC');
  }

  Future<int> deletePotentialContact(int id) async {
    final db = await database;
    return db.delete('potential_contact_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addPotentialUser({
    required String name, required String phone, String source = '',
    String language = '', String sports = '', String notes = '',
    String status = 'New Lead', DateTime? followUpDate, bool contactPermission = false,
  }) async {
    final db = await database;
    final cleanPhone = phone.trim();
    return db.transaction((txn) async {
      final registered = await txn.query('users', columns: ['id'],
        where: 'phone = ?', whereArgs: [cleanPhone], limit: 1);
      if (registered.isNotEmpty) {
        throw const DuplicatePhoneException('This phone number already belongs to a registered user.');
      }
      return txn.insert('potential_users', {
        'name': name.trim(), 'phone': cleanPhone, 'source': source.trim(),
        'language': language.trim(), 'sports': sports.trim(), 'notes': notes.trim(),
        'status': status,
        'follow_up_date': followUpDate?.toIso8601String().substring(0, 10),
        'contact_permission': contactPermission ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<int> updatePotentialUser({
    required int id, required String name, required String phone,
    required String source, required String language, required String sports,
    required String notes, required String status, DateTime? followUpDate,
    required bool contactPermission,
  }) async {
    final db = await database;
    final cleanPhone = phone.trim();
    return db.transaction((txn) async {
      final registered = await txn.query('users', columns: ['id'],
        where: 'phone = ?', whereArgs: [cleanPhone], limit: 1);
      if (registered.isNotEmpty) {
        throw const DuplicatePhoneException('This phone number already belongs to a registered user.');
      }
      return txn.update('potential_users', {
        'name': name.trim(), 'phone': cleanPhone, 'source': source.trim(),
        'language': language.trim(), 'sports': sports.trim(), 'notes': notes.trim(),
        'status': status,
        'follow_up_date': followUpDate?.toIso8601String().substring(0, 10),
        'contact_permission': contactPermission ? 1 : 0,
      }, where: 'id = ?', whereArgs: [id]);
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
        'notes': prospect['notes'],
        'preferred_language': prospect['language'] ?? '',
        'created_at': DateTime.now().toIso8601String(),
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
    validateBonusAmounts(amount, relatedDp);
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

  Future<Map<String, Object?>?> getUserProfile(int userId) async {
    final db = await database;
    final rows = await db.rawQuery("""
      SELECT u.*,
        COALESCE((SELECT SUM(total) FROM dp_entries WHERE user_id = u.id), 0) AS lifetime_dp,
        COALESCE((SELECT SUM(total) FROM dp_entries WHERE user_id = u.id AND entry_date >= date('now','localtime','start of month') AND entry_date < date('now','localtime','start of month','+1 month')), 0) AS monthly_dp,
        COALESCE((SELECT SUM(amount) FROM bonus_entries WHERE user_id = u.id), 0) AS lifetime_bonus,
        (SELECT MAX(entry_date) FROM dp_entries WHERE user_id = u.id) AS last_dp_date,
        CAST(julianday(date('now','localtime')) - julianday((SELECT MAX(entry_date) FROM dp_entries WHERE user_id = u.id)) AS INTEGER) AS days_since_last_dp,
        (SELECT MAX(contact_date) FROM contact_history WHERE user_id = u.id) AS last_contact_date,
        (SELECT COUNT(*) FROM dp_entries WHERE user_id = u.id) AS dp_transactions,
        (SELECT COUNT(*) FROM bonus_entries WHERE user_id = u.id) AS bonus_transactions
      FROM users u WHERE u.id = ? LIMIT 1
    """, [userId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>> getUserDpInsights(int userId) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    final startDate = start.toIso8601String().substring(0, 10);
    final endDate = now.toIso8601String().substring(0, 10);
    final rows = await db.rawQuery("""
      SELECT entry_date, SUM(total) AS day_total
      FROM dp_entries
      WHERE user_id = ? AND entry_date >= ? AND entry_date <= ?
      GROUP BY entry_date
      ORDER BY entry_date ASC
    """, [userId, startDate, endDate]);
    final totals = rows.map((r) => (r['day_total'] as num).toDouble()).toList();
    final dates = rows.map((r) => DateTime.parse(r['entry_date'] as String)).toList();
    final total = totals.fold<double>(0, (sum, value) => sum + value);
    final highest = totals.isEmpty ? 0.0 : totals.reduce((a, b) => a > b ? a : b);
    final timeRows = await db.rawQuery("""
      SELECT COUNT(*) AS record_count,
        AVG(CAST(strftime('%H', created_at) AS INTEGER) * 60 +
            CAST(strftime('%M', created_at) AS INTEGER)) AS usual_minute
      FROM dp_entries
      WHERE user_id = ?
        AND datetime(substr(created_at, 1, 19)) >= datetime('now', 'localtime', '-30 days')
    """, [userId]);
    final usualTimeCount = (timeRows.first['record_count'] as num).toInt();
    final usualMinute = usualTimeCount >= 3 ? timeRows.first['usual_minute'] as num? : null;
    var gapTotal = 0;
    for (var i = 1; i < dates.length; i++) {
      gapTotal += dates[i].difference(dates[i - 1]).inDays;
    }
    return {
      'total': total,
      'active_days': rows.length,
      'average_per_day': rows.isEmpty ? 0.0 : total / rows.length,
      'highest_day': highest,
      'average_gap': dates.length < 2 ? null : gapTotal / (dates.length - 1),
      'usual_minute': usualMinute,
      'usual_time_records': usualTimeCount,
    };
  }

  Future<List<Map<String, Object?>>> getUserTimeline(int userId) async {
    final db = await database;
    return db.rawQuery("""
      SELECT 'DP' AS kind, entry_date AS event_date, total AS amount,
        dp_count || ' DP item(s)' AS detail FROM dp_entries WHERE user_id = ?
      UNION ALL
      SELECT 'Bonus', entry_date, amount, reason FROM bonus_entries WHERE user_id = ?
      UNION ALL
      SELECT 'Contact', substr(contact_date, 1, 10), NULL,
        channel || ' · ' || outcome FROM contact_history WHERE user_id = ?
      UNION ALL
      SELECT 'Issue', substr(opened_at, 1, 10), NULL,
        title || ' · ' || status FROM customer_issues WHERE user_id = ?
      ORDER BY event_date DESC
    """, [userId, userId, userId, userId]);
  }

  Future<List<Map<String, Object?>>> getUsers({String search = '', int? includeArchivedId}) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month).toIso8601String().substring(0, 10);
    final end = DateTime(now.year, now.month + 1).toIso8601String().substring(0, 10);
    final term = search.trim();
    return db.rawQuery('''
      SELECT u.*,
        COALESCE((SELECT SUM(d.total) FROM dp_entries d WHERE d.user_id = u.id), 0) AS lifetime_dp,
        COALESCE((SELECT SUM(d.total) FROM dp_entries d WHERE d.user_id = u.id AND d.entry_date >= ? AND d.entry_date < ?), 0) AS monthly_dp,
      COALESCE((SELECT MAX(COALESCE(d.created_at, d.entry_date || 'T00:00:00')) FROM dp_entries d WHERE d.user_id = u.id), u.previous_dp_at) AS latest_dp_at
      FROM users u
      WHERE (u.archived = 0 OR u.id = ?) AND (? = '' OR u.name LIKE ? OR u.phone LIKE ?)
      ORDER BY CASE WHEN latest_dp_at IS NULL THEN 1 ELSE 0 END,
        latest_dp_at DESC, u.name COLLATE NOCASE
    ''', [start, end, includeArchivedId, term, '%$term%', '%$term%']);
  }

  Future<Map<String, int>> todayContactMetrics() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final users = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM users WHERE archived = 0',
    );
    // A user counts as contacted today if either a contact-history entry
    // exists or a DP record has its independent "contacted" checkbox enabled.
    // Count users once even when both sources contain today's activity.
    final contacted = await db.rawQuery(
      """SELECT COUNT(*) AS total
         FROM users u
         WHERE u.archived = 0 AND (
           EXISTS (
             SELECT 1 FROM contact_history c
             WHERE c.user_id = u.id AND substr(c.contact_date, 1, 10) = ?
           )
           OR EXISTS (
             SELECT 1 FROM dp_entries d
             WHERE d.user_id = u.id AND d.entry_date = ? AND d.contacted = 1
           )
         )""",
      [today, today],
    );
    final multipleDp = await db.rawQuery(
      """SELECT COUNT(DISTINCT user_id) AS total
         FROM dp_entries
         WHERE entry_date = ? AND dp_count > 1""",
      [today],
    );
    final totalUsers = Sqflite.firstIntValue(users) ?? 0;
    final contactedUsers = Sqflite.firstIntValue(contacted) ?? 0;
    return {
      'contacted': contactedUsers,
      'not_contacted': (totalUsers - contactedUsers).clamp(0, totalUsers).toInt(),
      'multiple_dp': Sqflite.firstIntValue(multipleDp) ?? 0,
    };
  }

  Future<int> countUsers() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM users WHERE archived = 0');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<Map<String, Object?>>> getActivityStatusUsers() async {
    final db = await database;
    return db.rawQuery("""
      WITH activity AS (
        SELECT u.id, u.name, u.phone, MAX(d.entry_date) AS last_dp_date
        FROM users u
        LEFT JOIN dp_entries d ON d.user_id = u.id
        WHERE u.archived = 0
        GROUP BY u.id, u.name, u.phone
      ),
      aged AS (
        SELECT *, CASE
          WHEN last_dp_date IS NULL THEN NULL
          ELSE CAST(julianday(date('now', 'localtime')) - julianday(last_dp_date) AS INTEGER)
        END AS days_since_last_dp
        FROM activity
      )
      SELECT *,
        CASE
          WHEN last_dp_date IS NULL THEN 'Never DP'
          WHEN days_since_last_dp <= 3 THEN 'Active'
          WHEN days_since_last_dp <= 7 THEN 'Follow-up'
          WHEN days_since_last_dp <= 14 THEN 'Inactive'
          WHEN days_since_last_dp <= 30 THEN 'Long inactive'
          ELSE 'Very long inactive'
        END AS activity_status
      FROM aged
      ORDER BY
        CASE activity_status
          WHEN 'Follow-up' THEN 1 WHEN 'Inactive' THEN 2
          WHEN 'Long inactive' THEN 3 WHEN 'Very long inactive' THEN 4
          WHEN 'Never DP' THEN 5 ELSE 0
        END,
        days_since_last_dp DESC, name COLLATE NOCASE
    """);
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

  Future<List<Map<String, Object?>>> getReportRows(DateTime start, DateTime end) async {
    final database = await this.database;
    final from = start.toIso8601String().substring(0, 10);
    final until = end.toIso8601String().substring(0, 10);
    return database.rawQuery("""
      SELECT 'DP' AS type, d.entry_date AS transaction_date, u.name AS user_name,
        u.phone AS phone, d.total AS amount, d.dp_count AS item_count,
        d.notes AS notes, '' AS reason
      FROM dp_entries d JOIN users u ON u.id = d.user_id
      WHERE d.entry_date >= ? AND d.entry_date < ?
      UNION ALL
      SELECT 'Bonus', b.entry_date, u.name, u.phone, b.amount, 1, b.notes, b.reason
      FROM bonus_entries b JOIN users u ON u.id = b.user_id
      WHERE b.entry_date >= ? AND b.entry_date < ?
      ORDER BY transaction_date DESC, type ASC, user_name COLLATE NOCASE
    """, [from, until, from, until]);
  }

  Future<Map<String, num>> getReportTotals(DateTime start, DateTime end) async {
    final database = await this.database;
    final from = start.toIso8601String().substring(0, 10);
    final until = end.toIso8601String().substring(0, 10);
    final dp = await database.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS total, COUNT(*) AS count FROM dp_entries WHERE entry_date >= ? AND entry_date < ?',
      [from, until],
    );
    final bonus = await database.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total, COUNT(*) AS count FROM bonus_entries WHERE entry_date >= ? AND entry_date < ?',
      [from, until],
    );
    return {
      'dp': dp.first['total'] as num,
      'dp_count': dp.first['count'] as num,
      'bonus': bonus.first['total'] as num,
      'bonus_count': bonus.first['count'] as num,
    };
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
    final values = validateDpAmounts(amounts);
    final count = values.where((v) => v > 0).length;
    final total = values.fold<double>(0, (sum, value) => sum + value);
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


  Future<double> todayDpTotal() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) AS total FROM dp_entries WHERE entry_date = ?',
      [today],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<double> todayBonusTotal() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM bonus_entries WHERE entry_date = ?',
      [today],
    );
    return (rows.first['total'] as num).toDouble();
  }

  Future<int> todayDpTransactions() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM dp_entries WHERE entry_date = ?',
      [today],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
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

  Future<Map<String, Object?>> createBackupData() async {
    final db = await database;
    final tables = <String>[
      'users', 'dp_entries', 'bonus_entries', 'potential_users',
      'contact_history', 'potential_contact_history', 'customer_issues', 'audit_log',
      'sports_interests', 'matches', 'user_level_settings', 'contact_reminders',
    ];
    final data = <String, Object?>{
      'app': 'User Hub',
      'format_version': 1,
      'created_at': DateTime.now().toIso8601String(),
    };
    for (final table in tables) {
      data[table] = await db.query(table);
    }
    return data;
  }

  Future<void> restoreBackupData(Map<String, dynamic> data) async {
    if (data['app'] != 'User Hub' || data['format_version'] != 1) {
      throw const FormatException('This is not a supported User Hub backup.');
    }
    final requiredTables = <String>[
      'users', 'dp_entries', 'bonus_entries', 'potential_users',
      'contact_history', 'customer_issues', 'audit_log',
      'sports_interests', 'matches',
      if (data['contact_reminders'] is List) 'contact_reminders',
    ];
    final tables = <String>[
      ...requiredTables,
      if (data['user_level_settings'] is List) 'user_level_settings',
    ];
    for (final table in tables) {
      if (data[table] is! List) {
        throw FormatException('Backup is missing the $table table.');
      }
      for (final row in data[table] as List) {
        if (row is! Map) throw FormatException('Invalid row in $table.');
      }
    }
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        'contact_reminders', 'user_level_settings', 'matches', 'audit_log', 'customer_issues', 'contact_history',
        'sports_interests', 'bonus_entries', 'dp_entries', 'potential_users', 'users',
      ]) {
        if (table == 'user_level_settings' && !tables.contains(table)) continue;
        await txn.delete(table);
      }
      for (final table in tables) {
        for (final item in data[table] as List) {
          final row = Map<String, Object?>.from(item as Map);
          await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> _createSportsTables(DatabaseExecutor db) async {
    await db.execute("""
      CREATE TABLE sports_interests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        sports TEXT NOT NULL DEFAULT '',
        teams TEXT NOT NULL DEFAULT '',
        players TEXT NOT NULL DEFAULT '',
        competitions TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        match_alerts INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT
      )
    """);
    await db.execute("""
      CREATE TABLE matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sport TEXT NOT NULL,
        competition TEXT NOT NULL DEFAULT '',
        home_team TEXT NOT NULL,
        away_team TEXT NOT NULL,
        start_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Upcoming',
        source_url TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    """);
    await db.execute('CREATE INDEX idx_matches_start ON matches(start_at)');
    await db.execute('CREATE INDEX idx_matches_sport ON matches(sport)');
  }

  Future<List<Map<String, Object?>>> getSportsInterests() async {
    final db = await database;
    return db.rawQuery("""
      SELECT s.*, u.name AS user_name, u.phone AS user_phone, u.do_not_contact AS do_not_contact
      FROM sports_interests s JOIN users u ON u.id = s.user_id
      WHERE u.archived = 0 ORDER BY u.name COLLATE NOCASE
    """);
  }

  Future<int> saveSportsInterest({
    required int userId, required String sports, required String teams,
    required String players, required String competitions, required String notes,
    required bool matchAlerts,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('sports_interests', {
      'user_id': userId, 'sports': sports.trim(), 'teams': teams.trim(),
      'players': players.trim(), 'competitions': competitions.trim(),
      'notes': notes.trim(), 'match_alerts': matchAlerts ? 1 : 0,
      'created_at': now, 'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getMatches({String search = ''}) async {
    final db = await database;
    final term = search.trim();
    return db.query('matches',
      where: "? = '' OR sport LIKE ? OR competition LIKE ? OR home_team LIKE ? OR away_team LIKE ?",
      whereArgs: [term, '%$term%', '%$term%', '%$term%', '%$term%'],
      orderBy: 'start_at ASC');
  }

  Future<int> addMatch({
    required String sport, required String competition,
    required String homeTeam, required String awayTeam,
    required DateTime startAt, required String status,
    String sourceUrl = '', String notes = '',
  }) async {
    final db = await database;
    return db.insert('matches', {
      'sport': sport, 'competition': competition.trim(),
      'home_team': homeTeam.trim(), 'away_team': awayTeam.trim(),
      'start_at': startAt.toIso8601String(), 'status': status,
      'source_url': sourceUrl.trim(), 'notes': notes.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateMatchStatus(int id, String status) async {
    final db = await database;
    return db.update('matches', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteMatch(int id) async {
    final db = await database;
    return db.delete('matches', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _createAuditLog(DatabaseExecutor db) async {
    await db.execute("""
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    """);
    await db.execute('CREATE INDEX idx_audit_created ON audit_log(created_at)');
    await db.execute('CREATE INDEX idx_audit_entity ON audit_log(entity_type, entity_id)');
  }

  Future<int> updateDpEntry({
    required int id, required int userId, required List<double> amounts,
    required bool contacted, required String notes,
  }) async {
    final values = validateDpAmounts(amounts);
    final count = values.where((v) => v > 0).length;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final db = await database;
    return db.transaction((txn) async {
      final oldRows = await txn.query('dp_entries', where: 'id = ?', whereArgs: [id], limit: 1);
      if (oldRows.isEmpty) return 0;
      final old = oldRows.first;
      await txn.update('dp_entries', {
        'dp1': values[0], 'dp2': values[1], 'dp3': values[2],
        'dp4': values[3], 'dp5': values[4], 'total': total,
        'dp_count': count, 'contacted': contacted ? 1 : 0, 'notes': notes.trim(),
        'user_id': userId,
      }, where: 'id = ?', whereArgs: [id]);
      await txn.insert('audit_log', {
        'entity_type': 'DP', 'entity_id': id, 'action': 'Edited',
        'details': 'User ID ${old['user_id']} → $userId · Date ${old['entry_date']} · Total ${old['total']} → $total',
        'created_at': DateTime.now().toIso8601String(),
      });
      return 1;
    });
  }

  Future<int> updateBonusEntry({
    required int id, required int userId, required double amount, required String reason,
    double? relatedDp, required String notes,
  }) async {
    validateBonusAmounts(amount, relatedDp);
    final db = await database;
    return db.transaction((txn) async {
      final oldRows = await txn.query('bonus_entries', where: 'id = ?', whereArgs: [id], limit: 1);
      if (oldRows.isEmpty) return 0;
      final old = oldRows.first;
      await txn.update('bonus_entries', {
        'amount': amount, 'reason': reason, 'related_dp': relatedDp, 'notes': notes.trim(),
        'user_id': userId,
      }, where: 'id = ?', whereArgs: [id]);
      await txn.insert('audit_log', {
        'entity_type': 'Bonus', 'entity_id': id, 'action': 'Edited',
        'details': 'User ID ${old['user_id']} → $userId · Date ${old['entry_date']} · Amount ${old['amount']} → $amount',
        'created_at': DateTime.now().toIso8601String(),
      });
      return 1;
    });
  }

  Future<int> deleteDpEntry(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query('dp_entries', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return 0;
      final row = rows.first;
      await txn.insert('audit_log', {
        'entity_type': 'DP', 'entity_id': id, 'action': 'Deleted',
        'details': 'User ID ${row['user_id']} · Date ${row['entry_date']} · Total ${row['total']}',
        'created_at': DateTime.now().toIso8601String(),
      });
      return txn.delete('dp_entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deleteBonusEntry(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query('bonus_entries', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return 0;
      final row = rows.first;
      await txn.insert('audit_log', {
        'entity_type': 'Bonus', 'entity_id': id, 'action': 'Deleted',
        'details': 'User ID ${row['user_id']} · Date ${row['entry_date']} · Amount ${row['amount']} · Reason ${row['reason']}',
        'created_at': DateTime.now().toIso8601String(),
      });
      return txn.delete('bonus_entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, Object?>>> getAuditLog() async {
    final db = await database;
    return db.query('audit_log', orderBy: 'created_at DESC', limit: 200);
  }

  Future<int> addUser({required String name, required String phone, String notes = '', bool doNotContact = false, String preferredLanguage = '', String preferredContactMethod = '', bool hasPreviousDp = false, DateTime? previousDpAt}) async {
    final db = await database;
    final cleanPhone = phone.trim();
    return db.transaction((txn) async {
      final prospect = await txn.query('potential_users', columns: ['id'],
        where: "phone = ? AND status != 'Registered'", whereArgs: [cleanPhone], limit: 1);
      if (prospect.isNotEmpty) {
        throw const DuplicatePhoneException('This phone number already exists in potential users. Convert that profile instead.');
      }
      return txn.insert('users', {
        'name': name.trim(), 'phone': cleanPhone, 'notes': notes.trim(),
        'do_not_contact': doNotContact ? 1 : 0,
        'preferred_language': preferredLanguage.trim(),
        'preferred_contact_method': preferredContactMethod.trim(),
        'previous_dp_at': hasPreviousDp ? previousDpAt?.toIso8601String() : null,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<int> updateUser({required int id, required String name, required String phone, String notes = '', bool doNotContact = false, String preferredLanguage = '', String preferredContactMethod = ''}) async {
    final db = await database;
    final cleanPhone = phone.trim();
    return db.transaction((txn) async {
      final prospect = await txn.query('potential_users', columns: ['id'],
        where: "phone = ? AND status != 'Registered'", whereArgs: [cleanPhone], limit: 1);
      if (prospect.isNotEmpty) {
        throw const DuplicatePhoneException('This phone number already exists in potential users. Resolve that profile before changing this number.');
      }
      return txn.update('users', {
        'name': name.trim(), 'phone': cleanPhone, 'notes': notes.trim(),
        'do_not_contact': doNotContact ? 1 : 0,
        'preferred_language': preferredLanguage.trim(),
        'preferred_contact_method': preferredContactMethod.trim(),
      }, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, Object?>>> getArchivedUsers() async {
    final db = await database;
    return db.rawQuery("""
      SELECT u.*,
        COALESCE((SELECT SUM(total) FROM dp_entries WHERE user_id = u.id), 0) AS lifetime_dp
      FROM users u WHERE u.archived = 1
      ORDER BY u.name COLLATE NOCASE
    """);
  }

  Future<int> restoreUser(int id) async {
    final db = await database;
    return db.update('users', {'archived': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> archiveUser(int id) async {
    final db = await database;
    return db.update('users', {'archived': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
