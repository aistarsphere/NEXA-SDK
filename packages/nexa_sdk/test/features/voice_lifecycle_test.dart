// App lifecycle during a call (plan A-04): a backgrounded call that nothing
// holds alive is ended deliberately (not left to the server's idle timeout),
// and returning to the foreground recovers a stalled reconnect at once.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';

final class _Allow implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

void main() {
  late MockRealtimeVoiceTransport transport;
  late MockVoiceProvisioner provisioner;
  late NexaClient client;

  setUp(() {
    transport = MockRealtimeVoiceTransport();
    provisioner = MockVoiceProvisioner();
  });

  tearDown(() => client.dispose());

  Future<NexaVoiceController> voice({
    Duration grace = const Duration(milliseconds: 60),
  }) async {
    client = await Nexa.initialize(
      config: testConfig(),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: fastMock(),
        voiceTransport: transport,
        voiceProvisioner: provisioner,
        permissionHandler: _Allow(),
      ),
      voiceOptions: NexaVoiceOptions(backgroundGrace: grace),
    );
    return client.voice;
  }

  Future<void> phase(NexaVoiceController v, VoiceState s) => waitFor(
    () => v.state.value.phase == s,
    reason: 'phase ${s.name} (now ${v.state.value.phase.name})',
  );

  Future<void> live(NexaVoiceController v) async {
    await v.start();
    await phase(v, VoiceState.listening);
  }

  testWidgets('background without a hold ends the call with reason '
      '"background" and DELETE', (tester) async {
    late NexaVoiceController v;
    await tester.runAsync(() async {
      v = await voice();
      await live(v);
      // Inside runAsync: the grace timer must run in real time.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await waitFor(() => v.state.value.phase == VoiceState.ended);
    });
    expect(v.state.value.endReason, 'background');
    expect(provisioner.ended, isNotEmpty);
  });

  testWidgets('a hold (call service / panel) keeps the call running', (
    tester,
  ) async {
    late NexaVoiceController v;
    await tester.runAsync(() async {
      v = await voice();
      v.keepAliveInBackground = () => true;
      await live(v);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    expect(v.state.value.isActive, isTrue);
    expect(provisioner.ended, isEmpty);
  });

  testWidgets('returning before the grace keeps the call', (tester) async {
    late NexaVoiceController v;
    await tester.runAsync(() async {
      v = await voice(grace: const Duration(milliseconds: 200));
      await live(v);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    expect(v.state.value.isActive, isTrue);
    expect(provisioner.ended, isEmpty);
  });

  testWidgets('resuming while reconnecting recovers at once', (tester) async {
    late NexaVoiceController v;
    await tester.runAsync(() async {
      v = await voice();
      v.keepAliveInBackground = () => true;
      await live(v);
      await transport.simulateDrop(reconnect: false);
      await phase(v, VoiceState.reconnecting);
      expect(provisioner.statusCalls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await waitFor(() => provisioner.statusCalls >= 1, reason: 'recover');
      await waitFor(() => transport.grants.length == 2, reason: 'rejoined');
    });
  });

  testWidgets('no call: lifecycle changes do nothing', (tester) async {
    late NexaVoiceController v;
    await tester.runAsync(() async {
      v = await voice();
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(v.state.value.phase, VoiceState.idle);
    expect(provisioner.ended, isEmpty);
  });
}
