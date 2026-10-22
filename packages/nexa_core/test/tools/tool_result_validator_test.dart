import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

void main() {
  const v = ToolResultValidator();

  group('ToolResultValidator', () {
    test('rejects non-object and missing kind', () {
      expect(v.parse('x'), isA<InvalidToolResult>());
      expect(v.parse(<String, Object?>{}), isA<InvalidToolResult>());
      expect(v.parse({'kind': 'nope'}), isA<InvalidToolResult>());
    });

    test('rejects malformed shape without throwing', () {
      final r = v.parse({'kind': 'restaurants', 'items': 'not-a-list'});
      expect(r, isA<InvalidToolResult>());
      expect(v.toRenderable(r), isA<ErrorToolResult>());
    });

    test('accepts a valid restaurants payload', () {
      final r = v.parse({
        'kind': 'restaurants',
        'items': [
          {'id': 'r1', 'name': 'A', 'rating': 4.5, 'price_tier': 2},
        ],
      });
      expect(r, isA<ValidToolResult>());
    });

    test('rejects semantic violations', () {
      expect(
        v.validate(
          const ToolResult.restaurants(
            items: [RestaurantResult(id: 'r', name: 'A', rating: 9)],
          ),
        ),
        isA<InvalidToolResult>(),
      );
      expect(
        v.validate(
          ToolResult.media(
            items: [
              MediaItem(
                kind: MediaKind.video,
                uri: Uri.parse('http://x/v.mp4'),
              ),
            ],
          ),
        ),
        isA<InvalidToolResult>(),
        reason: 'http scheme not allowed',
      );
      expect(
        v.validate(
          const ToolResult.selection(
            selection: SelectionSpec(
              id: 's',
              prompt: 'p',
              options: [
                SelectionOption(id: 'a', label: 'A'),
                SelectionOption(id: 'a', label: 'B'),
              ],
            ),
          ),
        ),
        isA<InvalidToolResult>(),
        reason: 'duplicate option ids',
      );
      expect(
        v.validate(
          const ToolResult.form(
            form: FormSpec(
              id: 'f',
              title: 't',
              fields: [
                FormFieldSpec(id: 'x', label: 'X', type: FormFieldType.select),
              ],
            ),
          ),
        ),
        isA<InvalidToolResult>(),
        reason: 'select without options',
      );
      expect(
        v.validate(
          const ToolResult.mapRoute(
            route: MapRoute(
              origin: GeoPoint(latitude: 91, longitude: 0),
              destination: GeoPoint(latitude: 0, longitude: 0),
            ),
          ),
        ),
        isA<InvalidToolResult>(),
      );
    });

    test('tool result inside an event is validated on deserialisation', () {
      final event =
          ConversationEvent.fromJson({
                'type': 'tool_result_received',
                'event_id': 'e',
                'session_id': 's',
                'sequence': 1,
                'occurred_at': '2026-10-22T12:00:00Z',
                'tool_call_id': 't',
                'message_id': 'm',
                'result': {
                  'kind': 'weather',
                  'weather': {'location_name': ''},
                },
              })
              as ToolResultReceivedEvent;
      expect(event.result, isA<ErrorToolResult>());
    });
  });
}
