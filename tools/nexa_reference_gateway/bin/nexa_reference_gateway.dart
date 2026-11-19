import 'dart:io';

import 'package:args/args.dart';
import 'package:nexa_reference_gateway/nexa_reference_gateway.dart';

/// `dart run tools/nexa_reference_gateway/bin/nexa_reference_gateway.dart`
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('host', defaultsTo: '127.0.0.1')
    ..addOption('port', defaultsTo: '8080')
    ..addOption('token-ttl', defaultsTo: '900', help: 'seconds')
    ..addOption('session-ttl', defaultsTo: '3600', help: 'seconds')
    ..addOption('quota', defaultsTo: '50', help: 'messages per application')
    ..addOption('voice-max-seconds', defaultsTo: '600')
    ..addOption('delta-ms', defaultsTo: '40')
    ..addOption(
      'livekit-url',
      help: 'LiveKit dev server, e.g. ws://127.0.0.1:7880 (enables liveVoice)',
    )
    ..addOption(
      'livekit-public-url',
      help: 'LiveKit URL handed to clients when it differs (emulators)',
    )
    ..addOption('livekit-key', defaultsTo: 'devkey')
    ..addOption('livekit-secret', defaultsTo: 'secret')
    ..addOption(
      'agent-audio',
      help: 'Audio file the mock agent publishes via `lk` (synthetic)',
    )
    ..addFlag('verbose', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);
  final r = parser.parse(args);
  if (r['help'] == true) {
    stdout.writeln(parser.usage);
    return;
  }
  final gw = await ReferenceGateway.start(
    host: r['host'] as String,
    port: int.parse(r['port'] as String),
    options: GatewayOptions(
      tokenTtl: Duration(seconds: int.parse(r['token-ttl'] as String)),
      sessionTtl: Duration(seconds: int.parse(r['session-ttl'] as String)),
      quotaPerApplication: int.parse(r['quota'] as String),
      deltaDelay: Duration(milliseconds: int.parse(r['delta-ms'] as String)),
      verbose: r['verbose'] == true,
    ),
    voice: VoiceOptions(
      liveKitUrl: r['livekit-url'] == null
          ? null
          : Uri.parse(r['livekit-url'] as String),
      liveKitPublicUrl: r['livekit-public-url'] == null
          ? null
          : Uri.parse(r['livekit-public-url'] as String),
      liveKitApiKey: r['livekit-key'] as String,
      liveKitApiSecret: r['livekit-secret'] as String,
      agentAudioFile: r['agent-audio'] as String?,
      maxSeconds: int.parse(r['voice-max-seconds'] as String),
    ),
  );
  if (r['livekit-url'] != null) {
    stdout.writeln(
      'Voice (DEV, mock agent): LiveKit ${r['livekit-url']} '
      '${r['agent-audio'] == null ? '(no agent audio)' : 'agent audio ${r['agent-audio']}'}',
    );
  }
  stdout.writeln(
    'NEXA reference gateway (DEV ONLY, contract $contractVersion) listening on '
    '${gw.uri}',
  );
  stdout.writeln('Mint a token: POST ${gw.uri}v1/dev/session-tokens');
  ProcessSignal.sigint.watch().listen((_) async {
    await gw.close();
    exit(0);
  });
}
