// Plan F-05: an assistant activation (wake phrase, assist gesture, lock
// screen) makes sure the server conversation exists before the call starts,
// so tools and saved turns work from the first sentence; an open
// conversation is joined, never duplicated.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_example/assistant/device_assistant.dart';

void main() {
  test('no conversation yet and the client can create one: create it', () {
    expect(
      ensureConversationOnActivation(
        hasConversation: false,
        canCreate: true,
        callActive: false,
      ),
      isTrue,
    );
  });

  test('an open conversation is joined, not recreated', () {
    expect(
      ensureConversationOnActivation(
        hasConversation: true,
        canCreate: true,
        callActive: false,
      ),
      isFalse,
    );
  });

  test('a call already running keeps its conversation', () {
    expect(
      ensureConversationOnActivation(
        hasConversation: false,
        canCreate: true,
        callActive: true,
      ),
      isFalse,
    );
  });

  test('a client without server conversations creates nothing', () {
    expect(
      ensureConversationOnActivation(
        hasConversation: false,
        canCreate: false,
        callActive: false,
      ),
      isFalse,
    );
  });
}
