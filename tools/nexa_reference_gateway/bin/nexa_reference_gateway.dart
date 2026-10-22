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
    ..addOption('delta-ms', defaultsTo: '40')
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
  );
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
