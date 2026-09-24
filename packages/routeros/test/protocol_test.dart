import 'dart:typed_data';

import 'package:routeros/src/protocol.dart';
import 'package:test/test.dart';

void main() {
  group('length prefix', () {
    // Boundaries of each encoding size, from the API documentation.
    const cases = {
      0x00: [0x00],
      0x7F: [0x7F],
      0x80: [0x80, 0x80],
      0x3FFF: [0xBF, 0xFF],
      0x4000: [0xC0, 0x40, 0x00],
      0x1FFFFF: [0xDF, 0xFF, 0xFF],
      0x200000: [0xE0, 0x20, 0x00, 0x00],
      0xFFFFFFF: [0xEF, 0xFF, 0xFF, 0xFF],
      0x10000000: [0xF0, 0x10, 0x00, 0x00, 0x00],
    };
    cases.forEach((length, bytes) {
      final hex = '0x${length.toRadixString(16)}';
      test('encodes $hex', () => expect(encodeLength(length), bytes));
      test('reads $hex', () {
        expect(readLength(Uint8List.fromList(bytes), 0), (
          length: length,
          size: bytes.length,
        ));
      });
    });

    test('returns null until the whole prefix has arrived', () {
      expect(readLength(Uint8List.fromList([0xC0, 0x40]), 0), isNull);
    });

    test('rejects reserved control bytes', () {
      expect(
        () => readLength(Uint8List.fromList([0xF8]), 0),
        throwsFormatException,
      );
    });
  });

  group('SentenceDecoder', () {
    test('round-trips a sentence fed one byte at a time', () {
      final words = ['!re', '=name=ether1', '=comment=${'x' * 200}', '.tag=7'];
      final decoder = SentenceDecoder();
      final sentences = [
        for (final byte in encodeSentence(words)) ...decoder.add([byte]),
      ];
      expect(sentences, [words]);
    });

    test('splits several sentences in one chunk', () {
      final bytes = [
        ...encodeSentence(['!re', '=a=1']),
        ...encodeSentence(['!done']),
      ];
      expect(SentenceDecoder().add(bytes), [
        ['!re', '=a=1'],
        ['!done'],
      ]);
    });

    test('decodes UTF-8 and tolerates invalid bytes', () {
      final decoder = SentenceDecoder();
      expect(decoder.add(encodeSentence(['=message=Wi-Fi “guest”'])), [
        ['=message=Wi-Fi “guest”'],
      ]);
      expect(decoder.add([2, 0x41, 0xFF, 0]), [
        ['A�'],
      ]);
    });
  });

  group('Reply.parse', () {
    test('reads type, tag and attributes', () {
      final reply = Reply.parse([
        '!re',
        '=.id=*1',
        '=comment=',
        '=script=:put a=b',
        '.tag=3',
      ]);
      expect(reply.type, '!re');
      expect(reply.tag, '3');
      expect(reply.attributes, {
        '.id': '*1',
        'comment': '',
        'script': ':put a=b',
      });
    });

    test('keeps the message of a !fatal reply', () {
      final reply = Reply.parse(['!fatal', 'session terminated on request']);
      expect(reply.fatalMessage, 'session terminated on request');
    });
  });
}
