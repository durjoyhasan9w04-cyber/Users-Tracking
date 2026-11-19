// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('User Hub premium dashboard renders', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: DashboardPage(onChanged: () {}, useGoogleFonts: false),
      ),
    ));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    // The refreshed light dashboard uses the new Dashboard title and Sales chart card.
    expect(find.text('Dashboard'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('DP Transactions'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('DP Transactions'), findsOneWidget);
    expect(find.text('Contacted Today'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sales'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sales'), findsOneWidget);
    // Quick actions sit below the recent-activity section in the scrollable dashboard.
    await tester.scrollUntilVisible(
      find.text('Record DP'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Record DP'), findsOneWidget);
    expect(find.text('Add Bonus'), findsOneWidget);
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
