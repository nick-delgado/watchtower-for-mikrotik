import 'package:routeros/routeros.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes openssl and RouterOS formats to the same value', () {
    expect(normalizeFingerprint('B1:89:A5:AB'), 'b189a5ab');
    expect(normalizeFingerprint('b189a5ab'), 'b189a5ab');
    expect(normalizeFingerprint(' b1 89 a5 ab '), 'b189a5ab');
  });

  test('formats as colon-separated uppercase bytes', () {
    expect(formatFingerprint('b189a5ab'), 'B1:89:A5:AB');
  });
}
