import 'dart:convert';
import 'dart:typed_data';

/// Encodes the length prefix of an API word.
///
/// See https://manual.mikrotik.com/docs/developer-guides/api/ ("API words").
Uint8List encodeLength(int length) {
  if (length < 0x80) return Uint8List.fromList([length]);
  if (length < 0x4000) {
    final l = length | 0x8000;
    return Uint8List.fromList([l >> 8, l & 0xFF]);
  }
  if (length < 0x200000) {
    final l = length | 0xC00000;
    return Uint8List.fromList([l >> 16, (l >> 8) & 0xFF, l & 0xFF]);
  }
  if (length < 0x10000000) {
    final l = length | 0xE0000000;
    return Uint8List.fromList([
      l >> 24,
      (l >> 16) & 0xFF,
      (l >> 8) & 0xFF,
      l & 0xFF,
    ]);
  }
  return Uint8List.fromList([
    0xF0,
    (length >> 24) & 0xFF,
    (length >> 16) & 0xFF,
    (length >> 8) & 0xFF,
    length & 0xFF,
  ]);
}

/// Reads a length prefix at [offset]. Returns null if [bytes] doesn't hold
/// the whole prefix yet.
({int length, int size})? readLength(Uint8List bytes, int offset) {
  if (offset >= bytes.length) return null;
  final first = bytes[offset];
  final int size;
  var length = 0;
  if ((first & 0x80) == 0x00) {
    size = 1;
    length = first;
  } else if ((first & 0xC0) == 0x80) {
    size = 2;
    length = first & 0x3F;
  } else if ((first & 0xE0) == 0xC0) {
    size = 3;
    length = first & 0x1F;
  } else if ((first & 0xF0) == 0xE0) {
    size = 4;
    length = first & 0x0F;
  } else if (first == 0xF0) {
    size = 5;
  } else {
    throw FormatException(
      'Unsupported control byte 0x${first.toRadixString(16)}',
    );
  }
  if (bytes.length - offset < size) return null;
  for (var i = 1; i < size; i++) {
    length = (length << 8) | bytes[offset + i];
  }
  return (length: length, size: size);
}

/// Encodes a sentence, including the empty word that terminates it.
Uint8List encodeSentence(List<String> words) {
  final builder = BytesBuilder(copy: false);
  for (final word in words) {
    final bytes = utf8.encode(word);
    builder
      ..add(encodeLength(bytes.length))
      ..add(bytes);
  }
  builder.addByte(0);
  return builder.takeBytes();
}

/// Turns a stream of byte chunks back into sentences. Words may be split
/// across chunks at any byte.
class SentenceDecoder {
  Uint8List _buffer = Uint8List(0);
  final _words = <String>[];

  /// Adds a chunk and returns every sentence it completes.
  List<List<String>> add(List<int> chunk) {
    _buffer = Uint8List.fromList([..._buffer, ...chunk]);
    final sentences = <List<String>>[];
    var offset = 0;
    while (true) {
      final prefix = readLength(_buffer, offset);
      if (prefix == null) break;
      final start = offset + prefix.size;
      if (_buffer.length - start < prefix.length) break;
      if (prefix.length == 0) {
        sentences.add(List.of(_words));
        _words.clear();
      } else {
        // RouterOS doesn't guarantee UTF-8 (e.g. log messages), so never throw.
        _words.add(
          utf8.decode(
            Uint8List.sublistView(_buffer, start, start + prefix.length),
            allowMalformed: true,
          ),
        );
      }
      offset = start + prefix.length;
    }
    _buffer = Uint8List.sublistView(_buffer, offset);
    return sentences;
  }
}

/// One reply sentence from the router.
class Reply {
  Reply._(this.words, this.tag, this.attributes);

  factory Reply.parse(List<String> words) {
    String? tag;
    final attributes = <String, String>{};
    for (final word in words.skip(1)) {
      if (word.startsWith('.tag=')) {
        tag = word.substring(5);
      } else if (word.startsWith('=')) {
        // Values may contain '=', so split only at the first one after the key.
        final split = word.indexOf('=', 1);
        if (split == -1) {
          attributes[word.substring(1)] = '';
        } else {
          attributes[word.substring(1, split)] = word.substring(split + 1);
        }
      }
    }
    return Reply._(words, tag, attributes);
  }

  final List<String> words;
  final String? tag;
  final Map<String, String> attributes;

  /// `!re`, `!done`, `!trap`, `!fatal` or `!empty`.
  String get type => words.isEmpty ? '' : words.first;

  /// `!fatal` carries its reason as a plain word, not an attribute.
  String get fatalMessage =>
      words.skip(1).where((w) => !w.startsWith('.tag=')).join(' ');
}
