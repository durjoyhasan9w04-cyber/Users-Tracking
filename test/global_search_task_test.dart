import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:user_hub/data/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('global activity search returns open task definitions and matches task kind', () async {
    final db = AppDatabase.instance;
    final marker = 'GlobalSearchTask-${DateTime.now().microsecondsSinceEpoch}';
    final taskId = await db.addTask(
      title: marker,
      notes: 'searchable task notes',
      taskType: 'daily',
    );

    try {
      final byTitle = await db.getUnifiedActivityEvents(
        search: marker,
        limit: 100,
      );
      final hit = byTitle.firstWhere(
        (event) => event['source'] == 'task_definition' &&
            event['record_id'] == taskId,
      );
      expect(hit['kind'], 'Task');
      expect(hit['detail'], contains('Open'));
      expect(hit['detail'], contains('searchable task notes'));

      final byCategory = await db.getUnifiedActivityEvents(
        search: 'Task',
        limit: 100,
      );
      expect(
        byCategory.any((event) =>
            event['source'] == 'task_definition' &&
            event['record_id'] == taskId),
        isTrue,
      );
    } finally {
      await db.deleteTask(taskId);
    }
  });
}
