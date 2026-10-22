import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/gateway/gateway_chat_transport.dart';
import 'package:nexa_sdk/src/data/gateway/gateway_dtos.dart';
import 'package:nexa_sdk/src/data/gateway/nexa_gateway_api.dart';

import '../helpers.dart';

class _Api extends Mock implements NexaGatewayApi {}

Map<String, Object?> raw(int seq, {String type = 'assistant_text_delta'}) => {
  'type': type,
  'event_id': 'e$seq',
  'session_id': 's',
  'sequence': seq,
  'occurred_at': '2026-10-22T12:00:00Z',
  if (type == 'assistant_text_delta') ...{
    'message_id': 'm',
    'delta_index': seq,
    'text': 'x',
  },
  if (type == 'session_ended') 'reason': 'user_ended',
};

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateSessionRequestDto(
        applicationId: '',
        requestedCapabilities: [],
        languageTag: 'en',
        sdkVersion: '',
        platform: '',
      ),
    );
    registerFallbackValue(
      const MessageRequestDto(clientMessageId: '', text: ''),
    );
  });

  late _Api api;
  late GatewayChatTransport transport;

  setUp(() {
    api = _Api();
    transport = GatewayChatTransport(
      api: api,
      dio: Dio(),
      config: testConfig(delivery: NexaEventDelivery.longPolling),
      logger: const NoopNexaLogger(),
      longPollWait: Duration.zero,
    );
  });

  tearDown(() => transport.dispose());

  group('GatewayChatTransport (proposed contract, mocked API)', () {
    test(
      'startSession maps DTO to SessionHandle and filters unknown capabilities',
      () async {
        when(() => api.createSession(any())).thenAnswer(
          (_) async => SessionDto(
            sessionId: 'ses',
            expiresAt: DateTime.utc(2027),
            grantedCapabilities: const ['textChat', 'somethingNew'],
            lastSequence: 4,
          ),
        );
        final h = await transport.startSession(
          credential: SessionCredential(
            token: 't',
            expiresAt: DateTime.utc(2027),
          ),
          requestedCapabilities: {NexaCapability.textChat},
          languageTag: 'en',
        );
        expect(h.sessionId, const SessionId('ses'));
        expect(h.grantedCapabilities, {NexaCapability.textChat});
        expect(h.lastSequence, 4);
        final sent =
            verify(() => api.createSession(captureAny())).captured.single
                as CreateSessionRequestDto;
        expect(sent.applicationId, 'app_test');
        expect(sent.requestedCapabilities, ['textChat']);
      },
    );

    test(
      'events: polls with advancing cursor, skips malformed, stops on done',
      () async {
        final pages = <EventPageDto>[
          EventPageDto(events: [raw(1), raw(2)], cursor: 2),
          EventPageDto(
            events: [
              {'type': 'garbage'},
              raw(3),
            ],
            cursor: 3,
          ),
          EventPageDto(
            events: [raw(4, type: 'session_ended')],
            cursor: 4,
            done: true,
          ),
        ];
        final seen = <int>[];
        when(() => api.pollEvents(any(), any(), any())).thenAnswer((inv) async {
          seen.add(inv.positionalArguments[1] as int);
          return pages.removeAt(0);
        });
        final events = await transport.events(const SessionId('s')).toList();
        expect(events.map((e) => e.sequence), [1, 2, 3, 4]);
        expect(seen, [0, 2, 3]);
      },
    );

    test('events: a failure ends the subscription with a mapped error '
        '(reconnect policy belongs to ChatBloc)', () async {
      var calls = 0;
      when(() => api.pollEvents(any(), any(), any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) return EventPageDto(events: [raw(1)], cursor: 1);
        throw DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        );
      });
      final received = <ConversationEvent>[];
      Object? error;
      try {
        await for (final e in transport.events(const SessionId('s'))) {
          received.add(e);
        }
      } on Object catch (e) {
        error = e;
      }
      expect(received.single.sequence, 1);
      expect(error, isA<NetworkException>());
      expect((error! as NexaException).retryable, isTrue);
      expect(calls, 2, reason: 'no internal retry loop');
    });

    test('events: session-level failures map to SessionExpired', () async {
      when(() => api.pollEvents(any(), any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: RequestOptions(),
            statusCode: 410,
          ),
        ),
      );
      expect(
        transport.events(const SessionId('s')).toList(),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test(
      'sendMessage uses clientMessageId as Idempotency-Key and maps errors',
      () async {
        when(
          () => api.postMessage(any(), any(), any()),
        ).thenAnswer((_) async {});
        await transport.sendMessage(
          const SessionId('s'),
          const OutgoingMessage(
            clientMessageId: ClientMessageId('cm1'),
            text: 'hi',
            languageTag: 'ar',
          ),
        );
        verify(() => api.postMessage('s', any(), 'cm1')).called(1);

        when(() => api.postMessage(any(), any(), any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.badResponse,
            response: Response<Object?>(
              requestOptions: RequestOptions(),
              statusCode: 429,
            ),
          ),
        );
        expect(
          transport.sendMessage(
            const SessionId('s'),
            const OutgoingMessage(
              clientMessageId: ClientMessageId('x'),
              text: 'y',
            ),
          ),
          throwsA(isA<RateLimitedException>()),
        );
      },
    );

    test('tool actions are serialised with the kind discriminator', () async {
      when(() => api.postToolAction(any(), any())).thenAnswer((_) async {});
      await transport.submitToolAction(
        const SessionId('s'),
        const ToolAction.confirmed(
          toolCallId: ToolCallId('t'),
          confirmationId: 'c',
        ),
      );
      final body =
          verify(() => api.postToolAction('s', captureAny())).captured.single
              as Map<String, Object?>;
      expect(body['kind'], 'confirmed');
      expect(body['tool_call_id'], 't');
    });

    test('disposed transport refuses calls', () async {
      await transport.dispose();
      expect(
        () => transport.events(const SessionId('s')),
        throwsA(isA<NotInitializedException>()),
      );
    });
  });
}
