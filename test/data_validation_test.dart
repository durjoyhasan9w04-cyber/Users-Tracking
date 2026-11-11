import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/data/app_database.dart';

void main() {
  group('DP amount validation', () {
    test('pads unused DP fields and accepts up to five amounts', () {
      expect(validateDpAmounts([10, 20]), [10, 20, 0, 0, 0]);
      expect(validateDpAmounts([1, 2, 3, 4, 5]), [1, 2, 3, 4, 5]);
    });

    test('rejects more than five amounts', () {
      expect(() => validateDpAmounts([1, 2, 3, 4, 5, 6]), throwsArgumentError);
    });

    test('rejects negative, infinite, and NaN amounts', () {
      expect(() => validateDpAmounts([-1]), throwsArgumentError);
      expect(() => validateDpAmounts([double.infinity]), throwsArgumentError);
      expect(() => validateDpAmounts([double.nan]), throwsArgumentError);
    });

    test('requires at least one positive amount but allows zero slots', () {
      expect(() => validateDpAmounts([0, 0, 0]), throwsArgumentError);
      expect(validateDpAmounts([0, 12]), [0, 12, 0, 0, 0]);
    });
  });

  group('Bonus amount validation', () {
    test('accepts a positive bonus and optional non-negative related DP', () {
      expect(() => validateBonusAmounts(10, null), returnsNormally);
      expect(() => validateBonusAmounts(10, 0), returnsNormally);
      expect(() => validateBonusAmounts(10, 5), returnsNormally);
    });

    test('rejects non-positive or non-finite bonus amounts', () {
      expect(() => validateBonusAmounts(0, null), throwsArgumentError);
      expect(() => validateBonusAmounts(-1, null), throwsArgumentError);
      expect(() => validateBonusAmounts(double.infinity, null), throwsArgumentError);
      expect(() => validateBonusAmounts(double.nan, null), throwsArgumentError);
    });

    test('rejects negative or non-finite related DP values', () {
      expect(() => validateBonusAmounts(10, -1), throwsArgumentError);
      expect(() => validateBonusAmounts(10, double.infinity), throwsArgumentError);
      expect(() => validateBonusAmounts(10, double.nan), throwsArgumentError);
    });
  });
}
