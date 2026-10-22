import 'dart:async';
import 'dart:convert';

/// One Server-Sent Events message.
final class SseMessage {
  const SseMessage({required this.data, this.id, this.event});

  final String data;
  final String? id;
  final String? event;
}

/// Decodes a `text/event-stream` byte stream into [SseMessage]s.
///
/// Implements the subset of the SSE spec the gateway uses: `data:` (joined
/// with `\n` when repeated), `id:`, `event:`, comment lines (`:`) and `retry:`
/// (ignored). A blank line dispatches the message. Pure Dart; unit-tested
/// independently of Dio.
Stream<SseMessage> decodeSse(Stream<List<int>> bytes) {
  String? id;
  String? event;
  final data = <String>[];
  late final StreamController<SseMessage> out;
  StreamSubscription<String>? sub;

  void dispatch() {
    if (data.isEmpty) {
      id = null;
      event = null;
      return;
    }
    out.add(SseMessage(data: data.join('\n'), id: id, event: event));
    data.clear();
    id = null;
    event = null;
  }

  out = StreamController<SseMessage>(
    onListen: () {
      // `cast` matters: a `Stream<Uint8List>` (what Dio emits) is not a
      // `Stream<List<int>>` for `transform`'s runtime check.
      sub = bytes
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.isEmpty) {
                dispatch();
                return;
              }
              if (line.startsWith(':')) return; // comment / keep-alive
              final colon = line.indexOf(':');
              final field = colon < 0 ? line : line.substring(0, colon);
              var value = colon < 0 ? '' : line.substring(colon + 1);
              if (value.startsWith(' ')) value = value.substring(1);
              switch (field) {
                case 'data':
                  data.add(value);
                case 'id':
                  id = value;
                case 'event':
                  event = value;
                default:
                  break; // retry and unknown fields are ignored
              }
            },
            onError: out.addError,
            onDone: () {
              dispatch();
              unawaited(out.close());
            },
          );
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}
