import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/data/app_database.dart';

void main() {
  group('Backup compatibility by database version', () {
    test('version 1 requires only the original users table', () {
      expect(requiredBackupTablesForVersion(1), {'users'});
    });

    test('each table is required only from its introduction version', () {
      expect(requiredBackupTablesForVersion(2), containsAll({'users', 'dp_entries'}));
      expect(requiredBackupTablesForVersion(3), contains('bonus_entries'));
      expect(requiredBackupTablesForVersion(4), contains('potential_users'));
      expect(requiredBackupTablesForVersion(5), contains('contact_history'));
      expect(requiredBackupTablesForVersion(6), contains('customer_issues'));
      expect(requiredBackupTablesForVersion(7), isNot(contains('audit_log')));
      expect(requiredBackupTablesForVersion(8), contains('audit_log'));
      expect(requiredBackupTablesForVersion(9), containsAll({'sports_interests', 'matches'}));
      expect(requiredBackupTablesForVersion(11), isNot(contains('user_level_settings')));
      expect(requiredBackupTablesForVersion(12), contains('user_level_settings'));
      expect(requiredBackupTablesForVersion(13), isNot(contains('contact_reminders')));
      expect(requiredBackupTablesForVersion(14), contains('contact_reminders'));
      expect(requiredBackupTablesForVersion(14), isNot(contains('potential_contact_history')));
      expect(requiredBackupTablesForVersion(15), contains('potential_contact_history'));
    });

    test('latest schema keeps the complete table set', () {
      expect(
        requiredBackupTablesForVersion(supportedUserHubDatabaseVersion),
        containsAll({
          'users', 'dp_entries', 'bonus_entries', 'potential_users',
          'contact_history', 'potential_contact_history', 'customer_issues', 'audit_log',
          'sports_interests', 'matches', 'user_level_settings', 'contact_reminders',
        }),
      );
    });

    test('rejects unsupported database versions', () {
      expect(() => requiredBackupTablesForVersion(0), throwsArgumentError);
      expect(() => requiredBackupTablesForVersion(15), throwsArgumentError);
    });
  });
}
