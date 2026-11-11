import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/models/user_level_config.dart';

void main() {
  group('UserLevelConfig', () {
    test('uses the default lifetime and monthly thresholds', () {
      const config = UserLevelConfig.defaults;
      expect(config.labelFor(10000, monthly: false), 'High Value');
      expect(config.labelFor(2999, monthly: false), 'Low Value');
      expect(config.labelFor(1500, monthly: true), 'Medium Value');
      expect(config.labelFor(199, monthly: true), 'Neighborly');
    });

    test('round trips through JSON', () {
      final restored = UserLevelConfig.fromJson(UserLevelConfig.defaults.toJson());
      expect(restored.labelFor(5000, monthly: true), 'High Value');
    });

    test('rejects unordered thresholds and duplicate labels', () {
      const unordered = UserLevelConfig(tiers: [
        UserLevelTier(key: 'neighborly', label: 'Neighborly', lifetimeMinimum: 0, monthlyMinimum: 0),
        UserLevelTier(key: 'low', label: 'Low', lifetimeMinimum: 500, monthlyMinimum: 200),
        UserLevelTier(key: 'medium', label: 'Medium', lifetimeMinimum: 300, monthlyMinimum: 1500),
        UserLevelTier(key: 'high', label: 'High', lifetimeMinimum: 10000, monthlyMinimum: 5000),
      ]);
      expect(unordered.validate, throwsArgumentError);
    });
  });
}
