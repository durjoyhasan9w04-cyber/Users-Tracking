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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE quiz_participants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            linked_user_id INTEGER,
            created_at TEXT NOT NULL,
            UNIQUE(phone)
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
        await db.execute('CREATE INDEX idx_quiz_date ON quizzes(quiz_date DESC)');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
    return _db!;
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

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
