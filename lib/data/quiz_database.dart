import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Quiz-only records live in quiz_participants.db. The User Hub database is
/// deliberately never opened or migrated by this class.
class QuizDatabase {
  QuizDatabase._();
  static final QuizDatabase instance = QuizDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'quiz_participants.db'),
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createQuizBonuses(db);
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE quiz_participants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            linked_user_id INTEGER,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE quizzes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            quiz_date TEXT NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE quiz_participations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            quiz_id INTEGER NOT NULL,
            participant_id INTEGER NOT NULL,
            participated_at TEXT NOT NULL,
            UNIQUE(quiz_id, participant_id),
            FOREIGN KEY(quiz_id) REFERENCES quizzes(id) ON DELETE CASCADE,
            FOREIGN KEY(participant_id) REFERENCES quiz_participants(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_quiz_participant_name ON quiz_participants(name COLLATE NOCASE)');
        await db.execute("CREATE UNIQUE INDEX idx_quiz_participant_phone ON quiz_participants(phone) WHERE phone != ''");
        await db.execute('CREATE INDEX idx_quiz_date ON quizzes(quiz_date DESC)');
        await db.execute('PRAGMA foreign_keys = ON');
        await _createQuizBonuses(db);
      },
      onOpen: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
    return _db!;
  }

  Future<void> _createQuizBonuses(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_bonus_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        participant_id INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        related_dp REAL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(participant_id) REFERENCES quiz_participants(id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quiz_bonus_date ON quiz_bonus_entries(entry_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quiz_bonus_participant ON quiz_bonus_entries(participant_id)');
  }

  Future<int> addQuizBonus({required int participantId, required DateTime date, required double amount, required String reason, double? relatedDp, String notes = ''}) async {
    if (amount <= 0 || !amount.isFinite || (relatedDp != null && (!relatedDp.isFinite || relatedDp < 0))) {
      throw ArgumentError('Invalid bonus amount.');
    }
    final db = await database;
    return db.insert('quiz_bonus_entries', {
      'participant_id': participantId,
      'entry_date': date.toIso8601String().substring(0, 10),
      'amount': amount,
      'reason': reason,
      'related_dp': relatedDp,
      'notes': notes.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getQuizBonusEntries() async {
    final db = await database;
    return db.rawQuery('''
      SELECT b.*, p.name AS user_name, p.phone AS user_phone,
        'Quiz participant' AS bonus_owner_type, p.id AS quiz_participant_id
      FROM quiz_bonus_entries b
      JOIN quiz_participants p ON p.id = b.participant_id
      ORDER BY b.entry_date DESC, b.id DESC
    ''');
  }

  Future<double> quizBonusTotal({DateTime? from, DateTime? until}) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (from != null) { clauses.add('entry_date >= ?'); args.add(from.toIso8601String().substring(0, 10)); }
    if (until != null) { clauses.add('entry_date < ?'); args.add(until.toIso8601String().substring(0, 10)); }
    final rows = await db.rawQuery('SELECT COALESCE(SUM(amount), 0) AS total FROM quiz_bonus_entries ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}', args);
    return (rows.first['total'] as num).toDouble();
  }


  Future<List<Map<String, Object?>>> getMonthlyQuizBonusBreakdown(
    DateTime month, {String reason = 'Special'}
  ) async {
    final db = await database;
    final start = DateTime(month.year, month.month).toIso8601String().substring(0, 10);
    final end = DateTime(month.year, month.month + 1).toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT p.id AS participant_id, p.name AS user_name, p.phone AS user_phone,
        COALESCE(SUM(b.amount), 0) AS total_amount, COUNT(b.id) AS record_count
      FROM quiz_bonus_entries b
      JOIN quiz_participants p ON p.id = b.participant_id
      WHERE b.entry_date >= ? AND b.entry_date < ? AND b.reason = ?
      GROUP BY p.id, p.name, p.phone
      ORDER BY p.name COLLATE NOCASE
    ''', [start, end, reason]);
  }

  Future<List<Map<String, Object?>>> getParticipants({String search = '', int? quizId}) async {
    final db = await database;
    final q = search.trim();
    return db.rawQuery('''
      SELECT p.*,
        (SELECT COUNT(*) FROM quiz_participations qp WHERE qp.participant_id=p.id) AS quiz_count,
        CASE WHEN ? IS NULL THEN 0 ELSE
          (SELECT COUNT(*) FROM quiz_participations qp WHERE qp.participant_id=p.id AND qp.quiz_id=?) END AS joined_selected
      FROM quiz_participants p
      WHERE (? = '' OR p.name LIKE ? OR p.phone LIKE ?)
      ORDER BY p.name COLLATE NOCASE
    ''', [quizId, quizId, q, '%$q%', '%$q%']);
  }

  Future<int> addParticipant({required String name, String phone = '', String notes = '', int? linkedUserId}) async {
    final db = await database;
    return db.insert('quiz_participants', {
      'name': name.trim(), 'phone': phone.trim(), 'notes': notes.trim(),
      'linked_user_id': linkedUserId, 'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateParticipant({
    required int id,
    required String name,
    required String phone,
    required String notes,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Participant name is required.');
    final db = await database;
    return db.update('quiz_participants', {
      'name': name.trim(),
      'phone': phone.trim(),
      'notes': notes.trim(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteParticipant(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('quiz_bonus_entries', where: 'participant_id = ?', whereArgs: [id]);
      await txn.delete('quiz_participations', where: 'participant_id = ?', whereArgs: [id]);
      await txn.delete('quiz_participants', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> linkRegularUser(int participantId, int userId) async {
    final db = await database;
    return db.update('quiz_participants', {'linked_user_id': userId},
      where: 'id = ?', whereArgs: [participantId]);
  }

  Future<int> addQuiz({required String title, required DateTime date, String notes = ''}) async {
    final db = await database;
    return db.insert('quizzes', {
      'title': title.trim(), 'quiz_date': date.toIso8601String().substring(0, 10),
      'notes': notes.trim(), 'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getQuizzes() async {
    final db = await database;
    return db.rawQuery('''
      SELECT q.*,
        (SELECT COUNT(*) FROM quiz_participations qp WHERE qp.quiz_id=q.id) AS participant_count
      FROM quizzes q ORDER BY q.quiz_date DESC, q.id DESC
    ''');
  }

  Future<int> deleteQuiz(int quizId) async {
    final db = await database;
    return db.delete('quizzes', where: 'id = ?', whereArgs: [quizId]);
  }

  Future<void> setParticipated({required int quizId, required int participantId, required bool participated}) async {
    final db = await database;
    if (participated) {
      await db.insert('quiz_participations', {
        'quiz_id': quizId, 'participant_id': participantId,
        'participated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('quiz_participations', where: 'quiz_id = ? AND participant_id = ?',
        whereArgs: [quizId, participantId]);
    }
  }


  Future<List<Map<String, Object?>>> getActivityEvents({int limit = 250, String search = ''}) async {
    final db = await database;
    return db.rawQuery('''
      SELECT * FROM (
        SELECT 'Quiz bonus' AS kind, b.entry_date AS event_date, b.created_at AS created_at,
          p.linked_user_id AS user_id, b.id AS record_id, p.name AS name,
          'Quiz bonus awarded' AS title, b.reason AS detail, b.amount AS amount,
          'quiz_bonus' AS source
        FROM quiz_bonus_entries b JOIN quiz_participants p ON p.id = b.participant_id
        UNION ALL
        SELECT 'Quiz participation', substr(qp.participated_at, 1, 10), qp.participated_at,
          p.linked_user_id, qp.id, p.name, 'Quiz participation', q.title, NULL, 'quiz_participation'
        FROM quiz_participations qp
        JOIN quiz_participants p ON p.id = qp.participant_id
        JOIN quizzes q ON q.id = qp.quiz_id
        UNION ALL
        SELECT 'Quiz', q.quiz_date, q.created_at, NULL, q.id, '',
          q.title, 'Quiz created', NULL, 'quiz'
        FROM quizzes q
      )
      WHERE (? = '' OR name LIKE ? OR title LIKE ? OR detail LIKE ?)
      ORDER BY created_at DESC, record_id DESC
      LIMIT ?
    ''', [search.trim(), '%${search.trim()}%', '%${search.trim()}%', '%${search.trim()}%', limit]);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
