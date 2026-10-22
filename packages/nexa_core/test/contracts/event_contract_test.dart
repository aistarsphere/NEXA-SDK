import 'dart:convert';
import 'dart:io';

import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

import '../helpers.dart';

/// Contract tests for the **proposed** gateway event wire format.
/// Fixtures live in docs/contracts/fixtures and are the hand-off artefact for
/// the backend team; if they change, this test must change with them.
void main() {
  final fixturesDir = Directory('../../docs/contracts/fixtures');

  group('ConversationEvent wire contract', () {
    test('round-trips every variant through JSON', () {
      final events = <ConversationEvent>[
        started(1),
        assistantStarted(2, 'a'),
        delta(3, 'a', 0, 'x'),
        completed(4, 'a', fullText: 'x'),
        failed(5, 'a'),
        accepted(6, 'c', 'u'),
        ConversationEvent.userMessageRejected(
          eventId: eid(),
          sessionId: session,
          sequence: 7,
          occurredAt: t0,
          clientMessageId: const ClientMessageId('c'),
          error: const EventError(code: 'policy', message: 'no'),
        ),
        ConversationEvent.messageCancelled(
          eventId: eid(),
          sessionId: session,
          sequence: 8,
          occurredAt: t0,
          messageId: const MessageId('a'),
        ),
        ConversationEvent.toolCallRequested(
          eventId: eid(),
          sessionId: session,
          sequence: 9,
          occurredAt: t0,
          messageId: const MessageId('a'),
          toolCall: const ToolCallRequest(
            id: ToolCallId('t'),
            toolName: 'x',
            displayTitle: 'X',
          ),
        ),
        ConversationEvent.toolExecutionProgress(
          eventId: eid(),
          sessionId: session,
          sequence: 10,
          occurredAt: t0,
          toolCallId: const ToolCallId('t'),
          status: ToolExecutionStatus.running,
          progress: 0.3,
        ),
        ConversationEvent.toolResultReceived(
          eventId: eid(),
          sessionId: session,
          sequence: 11,
          occurredAt: t0,
          toolCallId: const ToolCallId('t'),
          messageId: const MessageId('a'),
          result: const ToolResult.weather(
            weather: WeatherData(
              locationName: 'B',
              temperatureC: 30,
              condition: 'Clear',
            ),
          ),
        ),
        ConversationEvent.userConfirmationRequested(
          eventId: eid(),
          sessionId: session,
          sequence: 12,
          occurredAt: t0,
          toolCallId: const ToolCallId('t'),
          confirmation: const ConfirmationSpec(
            id: 'c',
            title: 'T',
            description: 'D',
          ),
        ),
        ConversationEvent.permissionRequested(
          eventId: eid(),
          sessionId: session,
          sequence: 13,
          occurredAt: t0,
          requestId: 'p',
          permission: NexaPermission.microphone,
        ),
        ConversationEvent.quotaUpdated(
          eventId: eid(),
          sessionId: session,
          sequence: 14,
          occurredAt: t0,
          quota: const QuotaInfo(kind: 'messages', remaining: 3, limit: 10),
        ),
        ConversationEvent.sessionEnded(
          eventId: eid(),
          sessionId: session,
          sequence: 15,
          occurredAt: t0,
          reason: SessionEndReason.userEnded,
        ),
      ];
      for (final e in events) {
        final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
        expect(json['type'], isA<String>());
        expect(json.containsKey('event_id'), isTrue, reason: 'snake_case keys');
        final back = ConversationEvent.fromJson(json);
        expect(back, equals(e), reason: json['type'].toString());
      }
    });

    test('ToolAction round-trips', () {
      const actions = [
        ToolAction.formSubmitted(
          toolCallId: ToolCallId('t'),
          formId: 'f',
          values: {'a': 1},
        ),
        ToolAction.optionSelected(
          toolCallId: ToolCallId('t'),
          selectionId: 's',
          optionIds: ['x'],
        ),
        ToolAction.confirmed(toolCallId: ToolCallId('t'), confirmationId: 'c'),
        ToolAction.declined(toolCallId: ToolCallId('t'), confirmationId: 'c'),
        ToolAction.cardActionTapped(toolCallId: ToolCallId('t'), actionId: 'a'),
        ToolAction.retryRequested(toolCallId: ToolCallId('t')),
      ];
      for (final a in actions) {
        final json = jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>;
        expect(json['kind'], isA<String>());
        expect(ToolAction.fromJson(json), equals(a));
      }
    });

    test('fixture files parse', () {
      final files = fixturesDir.existsSync()
          ? fixturesDir.listSync().whereType<File>().where(
              (f) => f.path.endsWith('.json'),
            )
          : const <File>[];
      expect(
        files,
        isNotEmpty,
        reason: 'fixtures must exist at ${fixturesDir.absolute.path}',
      );
      for (final f in files) {
        final decoded = jsonDecode(f.readAsStringSync());
        final list = decoded is List ? decoded : [decoded];
        for (final item in list) {
          expect(
            () => ConversationEvent.fromJson(item as Map<String, Object?>),
            returnsNormally,
            reason: f.path,
          );
        }
      }
    });
  });

  group('ConversationEvent.tryParse', () {
    const envelope = {
      'event_id': 'e9',
      'session_id': 's1',
      'sequence': 9,
      'occurred_at': '2026-10-22T12:00:00Z',
    };

    test('unknown type with a valid envelope becomes UnsupportedEvent', () {
      final e = ConversationEvent.tryParse({
        ...envelope,
        'type': 'assistant_mood_changed',
      });
      expect(e, isA<UnsupportedEvent>());
      expect(e!.sequence, 9);
      expect((e as UnsupportedEvent).originalType, 'assistant_mood_changed');
      expect(
        const ConversationReducer()
            .reduce(ConversationState.initial, e)
            .lastSequence,
        9,
      );
    });

    test(
      'known type with an invalid payload also becomes UnsupportedEvent',
      () {
        final e = ConversationEvent.tryParse({
          ...envelope,
          'type': 'assistant_text_delta',
          'message_id': 'm',
        });
        expect(e, isA<UnsupportedEvent>());
        expect((e! as UnsupportedEvent).reason, isNotEmpty);
      },
    );

    test('a broken envelope returns null', () {
      expect(ConversationEvent.tryParse({'type': 'garbage'}), isNull);
      expect(
        ConversationEvent.tryParse({...envelope, 'sequence': 'nine'}),
        isNull,
      );
    });
  });
}
