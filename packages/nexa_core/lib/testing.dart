/// **Mock adapters for tests and demos. Never wire these into a production
/// build.** Import as `package:nexa_core/testing.dart`.
///
/// * [MockAuthProvider] - issues fake session credentials locally.
/// * [MockChatTransport] - scripted in-memory chat backend.
/// * [MockRealtimeVoiceTransport] - scripted in-memory voice transport.
/// * [MockVoiceProvisioner] - issues fake voice grants locally.
library;

export 'src/mock/mock_auth_provider.dart';
export 'src/mock/mock_chat_transport.dart';
export 'src/mock/mock_realtime_voice_transport.dart';
export 'src/mock/mock_voice_provisioner.dart';
