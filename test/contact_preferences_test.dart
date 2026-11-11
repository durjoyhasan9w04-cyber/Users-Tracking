import 'package:flutter_test/flutter_test.dart';
import 'package:user_hub/main.dart';

void main() {
  group('Preferred contact channel', () {
    test('normalizes supported saved preferences', () {
      expect(normalizeContactChannel('WhatsApp'), 'WhatsApp');
      expect(normalizeContactChannel('Phone'), 'Phone call');
      expect(normalizeContactChannel('Phone call'), 'Phone call');
      expect(normalizeContactChannel('Call'), 'Phone call');
      expect(normalizeContactChannel('SMS'), 'SMS');
      expect(normalizeContactChannel('IMO'), 'IMO');
      expect(normalizeContactChannel('Other'), 'Other');
    });

    test('uses WhatsApp for blank or unsupported preferences', () {
      expect(normalizeContactChannel(null), 'WhatsApp');
      expect(normalizeContactChannel(''), 'WhatsApp');
      expect(normalizeContactChannel('Signal'), 'WhatsApp');
    });
  });
}
