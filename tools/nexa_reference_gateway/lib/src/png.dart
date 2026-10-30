import 'dart:io';
import 'dart:typed_data';

/// A tiny valid PNG (a two-colour stripe) used as the reference gateway's
/// image-job placeholder. It is labelled as a placeholder, never as a
/// generated image.
List<int> placeholderPng({int size = 96}) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < size; x++) {
      final stripe = ((x + y) ~/ 12).isEven;
      raw.add(stripe ? const [0x7B, 0x5A, 0x49] : const [0xEA, 0xD9, 0xCF]);
    }
  }
  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typeBytes = type.codeUnits;
    out
      ..add(_u32(data.length))
      ..add(typeBytes)
      ..add(data)
      ..add(_u32(_crc([...typeBytes, ...data])));
  }

  chunk('IHDR', [..._u32(size), ..._u32(size), 8, 2, 0, 0, 0]);
  chunk('IDAT', ZLibEncoder().convert(raw.takeBytes()));
  chunk('IEND', const []);
  return out.takeBytes();
}

List<int> _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}
