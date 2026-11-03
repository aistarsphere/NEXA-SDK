import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  late List<String> refs;
  var ids = 0;

  ConversationCoordinator make({
    Future<String> Function({required String clientRef})? create,
  }) => ConversationCoordinator(
    installationId: 'inst',
    newId: () => 'u${++ids}',
    create:
        create ??
        ({required clientRef}) async {
          refs.add(clientRef);
          return 'conv_${refs.length}';
        },
  );

  setUp(() {
    refs = [];
    ids = 0;
  });

  test('client_ref stays stable across failed attempts, then clears', () async {
    var attempts = 0;
    final c = make(
      create: ({required clientRef}) async {
        refs.add(clientRef);
        if (++attempts <= 3) {
          throw const NetworkException(NexaErrorCode.networkUnreachable, 'x');
        }
        return 'conv_ok';
      },
    );
    for (var i = 0; i < 3; i++) {
      await expectLater(
        c.ensureConversation(reason: 't'),
        throwsA(isA<NexaException>()),
      );
    }
    expect(await c.ensureConversation(reason: 't'), 'conv_ok');
    expect(refs, hasLength(4));
    expect(refs.toSet(), {'inst:u1'});
    expect(c.conversationId, 'conv_ok');

    // The next conversation after startNew gets a different ref.
    c.startNew();
    await c.ensureConversation(reason: 't');
    expect(refs.last, 'inst:u2');
  });

  test('concurrent ensure calls share one create', () async {
    final gate = Completer<String>();
    var calls = 0;
    final c = make(
      create: ({required clientRef}) {
        calls++;
        return gate.future;
      },
    );
    final a = c.ensureConversation(reason: 'chat');
    final b = c.ensureConversation(reason: 'voice');
    gate.complete('conv_x');
    expect(await a, 'conv_x');
    expect(await b, 'conv_x');
    expect(calls, 1);
  });

  test('ensure returns the open id without a create', () async {
    final c = make()..open('conv_9');
    expect(await c.ensureConversation(reason: 't'), 'conv_9');
    expect(refs, isEmpty);
    expect(c.resumePending, isTrue);
  });

  test('startNew clears id, seq and resume flag; notifies', () async {
    final c = make()
      ..open('conv_9')
      ..noteSeq(7);
    var notified = 0;
    c
      ..addListener(() => notified++)
      ..startNew();
    expect(c.conversationId, isNull);
    expect(c.lastKnownSeq, 0);
    expect(c.resumePending, isFalse);
    expect(notified, 1);
  });

  test('noteSeq only moves forward', () {
    final c = make()
      ..noteSeq(5)
      ..noteSeq(3);
    expect(c.lastKnownSeq, 5);
  });

  test('startNew during an in-flight create discards its result', () async {
    final gate = Completer<String>();
    final c = make(
      create: ({required clientRef}) {
        refs.add(clientRef);
        return gate.future;
      },
    );
    final first = c.ensureConversation(reason: 't');
    c.startNew();
    gate.complete('conv_stale');
    // The caller still gets the id it asked for, but it is not adopted.
    expect(await first, 'conv_stale');
    expect(c.conversationId, isNull);
  });

  test(
    'open during an in-flight create keeps the opened conversation',
    () async {
      final gate = Completer<String>();
      final c = make(create: ({required clientRef}) => gate.future);
      final first = c.ensureConversation(reason: 't');
      c.open('conv_picked');
      gate.complete('conv_stale');
      await first;
      expect(c.conversationId, 'conv_picked');
    },
  );

  test('adopt takes the server-assigned id and notifies on change', () {
    final c = make();
    var notified = 0;
    c
      ..addListener(() => notified++)
      ..adopt('conv_a')
      ..adopt('conv_a')
      ..adopt(null);
    expect(c.conversationId, 'conv_a');
    expect(notified, 1);
  });
}
