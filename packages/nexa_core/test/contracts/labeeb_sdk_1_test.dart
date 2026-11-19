import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

Map<String, Object?> _envelope(String type, Map<String, Object?> fields) => {
  'type': type,
  'event_id': 'evt_1',
  'session_id': 'ses_1',
  'sequence': 7,
  'occurred_at': '2026-10-28T10:00:00.000Z',
  ...fields,
};

Map<String, Object?> _call(String status, {String side = 'client'}) => {
  'tool_call_id': 'tc_1',
  'tool': 'device.location.get_current',
  'side': side,
  'arguments': {'accuracy': 'fine'},
  'status': status,
  'approval_required': true,
  'deadline_at': '2026-10-28T10:00:30.000Z',
  'result': null,
  'error': null,
  'asynchronous': false,
};

void main() {
  group('labeeb.sdk/1 events', () {
    for (final phase in [
      'tool_call_requested',
      'tool_call_updated',
      'tool_call_completed',
      'tool_call_failed',
    ]) {
      test('$phase parses to the contract tool call', () {
        final e = ConversationEvent.tryParse(
          _envelope(phase, _call('awaiting_approval')),
        )!;
        expect(e, isA<ContractToolCallEvent>());
        final c = NexaToolCall.fromJson((e as ContractToolCallEvent).call)!;
        expect(c.id, 'tc_1');
        expect(c.isClient, isTrue);
        expect(c.status, NexaToolCallStatus.awaitingApproval);
        expect(c.approvalRequired, isTrue);
        expect(c.arguments['accuracy'], 'fine');
        expect(c.deadlineAt, isNotNull);
        expect(e.sequence, 7);
      });
    }

    test('progress, asset_created, ui_presented', () {
      final p = ConversationEvent.tryParse(
        _envelope('tool_call_progress', {
          'tool_call_id': 'tc_9',
          'tool': 'image.generate',
          'state': 'reserving',
          'waited_s': 12,
        }),
      )!;
      expect(p, isA<ToolCallProgressEvent>());
      expect((p as ToolCallProgressEvent).waitedS, 12);
      expect(p.state, 'reserving');

      final a =
          ConversationEvent.tryParse(
                _envelope('asset_created', {
                  'tool_call_id': 'tc_9',
                  'message_id': 'msg_1',
                  'asset': {
                    'id': 'ast_1',
                    'kind': 'image',
                    'mime': 'image/png',
                    'size_bytes': 10,
                    'origin': 'generated',
                  },
                }),
              )!
              as AssetCreatedEvent;
      final ref = NexaAssetRef.fromJson(a.asset)!;
      expect(ref.generated, isTrue);
      expect(ref.isImage, isTrue);

      final u = ConversationEvent.tryParse(
        _envelope('ui_presented', {
          'tool_call_id': 'tc_9',
          'ui': {'schema': 'nexa.ui/1', 'id': 'ui_1'},
        }),
      )!;
      expect(u, isA<UiPresentedEvent>());
    });

    test('unknown statuses and fields are tolerated', () {
      final c = NexaToolCall.fromJson({
        ..._call('paused_by_future_server', side: 'server'),
        'brand_new_field': 1,
      })!;
      expect(c.status, NexaToolCallStatus.unknown);
      expect(c.status.terminal, isFalse);
      expect(c.isClient, isFalse);
    });

    test('answer bodies', () {
      expect(const NexaToolCallAnswer.success({'opened': true}).toJson(), {
        'result': {'opened': true},
      });
      expect(
        const NexaToolCallAnswer.failure(
          NexaToolCallError('permission_denied', message: 'no'),
        ).toJson(),
        {
          'error': {
            'code': 'permission_denied',
            'message': 'no',
            'retryable': false,
          },
        },
      );
    });
  });

  group('nexa.ui/1 documents', () {
    Map<String, Object?> doc(Map<String, Object?> root) => {
      'schema': 'nexa.ui/1',
      'id': 'ui_places_1',
      'category': 'places_maps',
      'presentation': 'inline_card',
      'title': {'en': 'Nearby', 'ar': 'قريب'},
      'root': root,
    };

    test('tree, options with ordinals, actions', () {
      final d = parseNexaUiDocument(
        doc({
          'id': 'col',
          'type': 'column',
          'children': [
            {
              'id': 'pick',
              'type': 'choice',
              'options': [
                {'id': 'p_b', 'label': 'B', 'ordinal': 2},
                {'id': 'p_a', 'label': 'A', 'ordinal': 1},
              ],
              'on_select': {'type': 'send_ui_event', 'event': 'select'},
            },
            {'id': 'x', 'type': 'hologram'},
            {
              'id': 'lnk',
              'type': 'link',
              'url': 'https://example.com',
              'action': {'type': 'open_url', 'url': 'http://insecure.test'},
            },
          ],
        }),
      );
      expect(d.titleFor('ar'), 'قريب');
      expect([for (final n in d.nodes) n.id], ['col', 'pick', 'lnk']);
      final pick = d.node('pick')!;
      expect(pick.options.first.id, 'p_a');
      expect(pick.optionByOrdinal(2)!.id, 'p_b');
      expect(pick.actions['on_select']!.event, 'select');
      // http is rejected: the action survives without a URL.
      expect(d.node('lnk')!.actions['action']!.url, isNull);
    });

    test('limits, schema and ids are enforced', () {
      expect(
        () => parseNexaUiDocument({...doc({}), 'schema': 'nexa.ui/2'}),
        throwsA(isA<NexaUiDocumentException>()),
      );
      Map<String, Object?> deep(int n) => n == 0
          ? {'id': 'leaf', 'type': 'text', 'text': 'x'}
          : {
              'id': 'n$n',
              'type': 'column',
              'children': [deep(n - 1)],
            };
      expect(() => parseNexaUiDocument(doc(deep(5))), returnsNormally);
      expect(
        () => parseNexaUiDocument(doc(deep(6))),
        throwsA(isA<NexaUiDocumentException>()),
      );
      expect(
        () => parseNexaUiDocument(
          doc({
            'id': 'g',
            'type': 'grid',
            'items': [
              for (var i = 0; i < 200; i++)
                {'id': 'i$i', 'type': 'text', 'text': '$i'},
            ],
          }),
        ),
        throwsA(isA<NexaUiDocumentException>()),
      );
      expect(
        () => parseNexaUiDocument(
          doc({
            'id': 'r',
            'type': 'row',
            'children': [
              {'id': 'dup', 'type': 'text'},
              {'id': 'dup', 'type': 'text'},
            ],
          }),
        ),
        throwsA(isA<NexaUiDocumentException>()),
      );
    });

    test('an unknown root type is kept without a tree (fallback text)', () {
      final d = parseNexaUiDocument({
        ...doc({'id': 'x', 'type': 'hologram'}),
        'fallback_text': {'en': 'Plain words', 'ar': 'كلمات'},
      });
      expect(d.root, isNull);
      expect(d.truncated, isFalse);
      expect(d.fallbackFor('en'), 'Plain words');
      expect(d.fallbackFor('ar'), 'كلمات');
      expect(
        parseNexaUiDocument({
          ...doc({'id': 'x', 'type': 'hologram'}),
          'fallback_text': 'Just text',
        }).fallbackFor('ar'),
        'Just text',
      );
    });

    test('a missing or malformed root is still invalid', () {
      expect(
        () => parseNexaUiDocument({...doc({}), 'root': null}),
        throwsA(isA<NexaUiDocumentException>()),
      );
      expect(
        () => parseNexaUiDocument({...doc({}), 'root': 'text'}),
        throwsA(isA<NexaUiDocumentException>()),
      );
    });

    test('truncated voice document keeps id and category only', () {
      final d = parseNexaUiDocument({
        'id': 'ui_big',
        'category': 'news_articles',
        'truncated': true,
      }, toolCallId: 'tc_3');
      expect(d.truncated, isTrue);
      expect(d.root, isNull);
      expect(d.toolCallId, 'tc_3');
    });

    test('ui_event body', () {
      expect(
        const NexaUiEvent(
          uiId: 'ui_1',
          componentId: 'pick',
          event: 'select',
          optionIds: ['p_b'],
        ).toJson(),
        {
          'ui_id': 'ui_1',
          'component_id': 'pick',
          'event': 'select',
          'option_ids': ['p_b'],
        },
      );
    });
  });
}
