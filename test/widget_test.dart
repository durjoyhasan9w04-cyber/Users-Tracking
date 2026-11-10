import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/main.dart';

void main() {
  testWidgets('User Hub premium dashboard renders', (tester) async {
    await tester.pumpWidget(const UserHubApp());
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('DP this month'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Add user'), findsOneWidget);
  });

  group('DP classification thresholds', () {
    test('lifetime levels use the configured boundaries', () {
      expect(dpLevel(0, monthly: false), 'Neighborly');
      expect(dpLevel(499, monthly: false), 'Neighborly');
      expect(dpLevel(500, monthly: false), 'Low');
      expect(dpLevel(2999, monthly: false), 'Low');
      expect(dpLevel(3000, monthly: false), 'Medium');
      expect(dpLevel(9999, monthly: false), 'Medium');
      expect(dpLevel(10000, monthly: false), 'High');
    });

    test('monthly levels use the configured boundaries', () {
      expect(dpLevel(199, monthly: true), 'Neighborly');
      expect(dpLevel(200, monthly: true), 'Low');
      expect(dpLevel(1499, monthly: true), 'Low');
      expect(dpLevel(1500, monthly: true), 'Medium');
      expect(dpLevel(4999, monthly: true), 'Medium');
      expect(dpLevel(5000, monthly: true), 'High');
    });
  });
}
