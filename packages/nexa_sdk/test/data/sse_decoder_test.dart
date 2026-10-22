import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/src/data/gateway/sse_decoder.dart';

Stream<List<int>> chunks(List<String> parts) =>
    Stream.fromIterable(parts.map(utf8.encode));

void main() {
  group('decodeSse', () {
    test('parses id/data/event and ignores comments and retry', () async {
      final messages = await decodeSse(
        chunks([
          'retry: 1000\n\n',
          ': keep-alive\n\n',
          'id: 1\ndata: {"a":1}\n\n',
          'event: custom\ndata: x\ndata: y\n\n',
        ]),
      ).toList();
      expect(messages.length, 2);
      expect(messages[0].id, '1');
      expect(messages[0].data, '{"a":1}');
      expect(messages[1].event, 'custom');
      expect(messages[1].data, 'x\ny');
    });

    test('reassembles messages split across byte chunks', () async {
      final messages = await decodeSse(
        chunks(['id: 7\nda', 'ta: {"se', 'q":7}\n', '\nid: 8\ndata: {}\n\n']),
      ).toList();
      expect(messages.map((m) => m.id), ['7', '8']);
      expect(messages.first.data, '{"seq":7}');
    });

    test('dispatches a trailing message without a final blank line', () async {
      final messages = await decodeSse(chunks(['data: tail'])).toList();
      expect(messages.single.data, 'tail');
    });

    test('accepts a Stream<Uint8List> (Dio response bodies)', () async {
      final bytes = Stream<Uint8List>.fromIterable([
        Uint8List.fromList(utf8.encode('id: 1\ndata: {}\n\n')),
      ]);
      final messages = await decodeSse(bytes).toList();
      expect(messages.single.id, '1');
    });

    test('propagates upstream errors', () async {
      final controller = StreamController<List<int>>();
      final future = decodeSse(controller.stream).toList();
      controller
        ..add(utf8.encode('data: ok\n\n'))
        ..addError(StateError('boom'));
      await controller.close();
      await expectLater(future, throwsA(isA<StateError>()));
    });
  });
}
