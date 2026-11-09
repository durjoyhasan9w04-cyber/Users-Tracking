import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/main.dart';

void main() {
  testWidgets('User Hub dashboard renders', (tester) async {
    await tester.pumpWidget(const UserHubApp());
    expect(find.text('USER HUB'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
  });
}
