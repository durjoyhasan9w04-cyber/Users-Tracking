import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/main.dart';

void main() {
  testWidgets('User Hub premium dashboard renders', (tester) async {
    await tester.pumpWidget(const UserHubApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('DP this month'), findsOneWidget);
  });

  group('DP classification thresholds', () {
    test('lifetime levels use the configured boundaries', () {
      expect(dpLevel(0, monthly: false), 'Neighborly');
      expect(dpLevel(499, monthly: false), 'Neighborly');
      expect(dpLevel(500, monthly: false), 'Low Value');
      expect(dpLevel(2999, monthly: false), 'Low Value');
      expect(dpLevel(3000, monthly: false), 'Medium Value');
      expect(dpLevel(9999, monthly: false), 'Medium Value');
      expect(dpLevel(10000, monthly: false), 'High Value');
    });

    test('monthly levels use the configured boundaries', () {
      expect(dpLevel(199, monthly: true), 'Neighborly');
      expect(dpLevel(200, monthly: true), 'Low Value');
      expect(dpLevel(1499, monthly: true), 'Low Value');
      expect(dpLevel(1500, monthly: true), 'Medium Value');
      expect(dpLevel(4999, monthly: true), 'Medium Value');
      expect(dpLevel(5000, monthly: true), 'High Value');
    });
  });
}
