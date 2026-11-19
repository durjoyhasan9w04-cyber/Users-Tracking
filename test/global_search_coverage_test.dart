import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/services/global_search_catalog.dart';

void main() {
  group('findSearchableReports', () {
    test('finds DP reports from common terms', () {
      expect(findSearchableReports('deposit').single.title,
          'DP transaction report');
      expect(findSearchableReports('DP').single.title,
          'DP transaction report');
    });

    test('prefers the most specific bonus report destination', () {
      expect(findSearchableReports('bonus').single.title,
          'Bonus distribution report');
      expect(findSearchableReports('participant bonus').single.title,
          'Quiz bonus report');
      expect(findSearchableReports('quiz bonus').single.title,
          'Quiz bonus report');
    });

    test('finds combined reports and ignores unrelated terms', () {
      expect(findSearchableReports('all transactions').single.title,
          'Combined transaction report');
      expect(findSearchableReports('unrelated').isEmpty, isTrue);
      expect(findSearchableReports('').isEmpty, isTrue);
    });
  });
}
