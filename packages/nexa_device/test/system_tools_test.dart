import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';

import 'device_tools_test.dart' show FakeLocation, FakeOpener;

final class _Net implements NexaNetworkPlatform {
  _Net(this.types, [this.ssid]);
  final List<String> types;
  final String? ssid;
  @override
  Future<List<String>> connectionTypes() async => types;
  @override
  Future<String?> wifiName() async => ssid;
}

final class _Sheet implements NexaShareSheet {
  _Sheet(this.status);
  final String status;
  final calls = <(String?, Uri?, List<String>)>[];
  @override
  Future<String> share({
    String? text,
    Uri? uri,
    List<String> filePaths = const [],
  }) async {
    calls.add((text, uri, filePaths));
    return status;
  }
}

final class _Picker implements NexaFilePicker {
  _Picker(this.file);
  final PickedFile? file;
  @override
  Future<PickedFile?> pickFile() async => file;
}

ClientToolRequest _req(String tool, [Map<String, Object?> args = const {}]) =>
    ClientToolRequest(
      callId: 'c',
      toolId: tool,
      version: 1,
      arguments: args,
      origin: ClientToolOrigin.user,
    );

Future<ClientToolResult> _run(
  ClientToolExecutor t, [
  Map<String, Object?> a = const {},
]) => t.execute(_req(t.descriptor.id, a), onPhase: (_) {});

void main() {
  test('network status: types only, no approval', () async {
    final t = NetworkStatusTool(network: _Net(['wifi', 'vpn']));
    expect(t.descriptor.requiresApproval, isFalse);
    final r = await _run(t);
    expect(r.output, {
      'connected': true,
      'types': ['wifi', 'vpn'],
    });
    expect(
      (await _run(NetworkStatusTool(network: _Net([])))).output!['connected'],
      isFalse,
    );
  });

  test('wifi: SSID only where permitted; never a password', () async {
    final granted = FakeLocation(state: LocationPermissionState.granted);
    final ok = await _run(
      WifiInfoTool(network: _Net(['wifi'], 'Home'), location: granted),
    );
    expect(ok.output, {
      'on_wifi': true,
      'ssid_available': true,
      'ssid': 'Home',
    });
    expect(ok.output!.keys.any((k) => k.contains('pass')), isFalse);

    final hidden = await _run(
      WifiInfoTool(network: _Net(['wifi']), location: granted),
    );
    expect(hidden.output!['ssid_unavailable_reason'], 'not_permitted_by_os');

    final denied = await _run(
      WifiInfoTool(
        network: _Net(['wifi'], 'Home'),
        location: FakeLocation(afterRequest: LocationPermissionState.denied),
      ),
    );
    expect(denied.output!['ssid_unavailable_reason'], 'permission_denied');
    expect(denied.output!.containsKey('ssid'), isFalse);

    final mobile = await _run(
      WifiInfoTool(network: _Net(['mobile']), location: granted),
    );
    expect(mobile.output!['ssid_unavailable_reason'], 'not_on_wifi');
  });

  test('browser: https only, no credentials, host allowlist', () async {
    expect(validateBrowserUrl('https://flutter.dev/docs'), isNotNull);
    expect(validateBrowserUrl('http://flutter.dev'), isNull);
    expect(validateBrowserUrl('javascript:alert(1)'), isNull);
    expect(validateBrowserUrl('file:///etc/passwd'), isNull);
    expect(validateBrowserUrl('https://user:pw@evil.com'), isNull);
    expect(
      validateBrowserUrl(
        'https://docs.flutter.dev',
        allowedHosts: {'flutter.dev'},
      ),
      isNotNull,
    );
    expect(
      validateBrowserUrl('https://evil.com', allowedHosts: {'flutter.dev'}),
      isNull,
    );
    final opener = FakeOpener();
    final r = await _run(BrowserOpenTool(opener: opener), {
      'url': 'https://flutter.dev',
    });
    expect(r.output, {'url': 'https://flutter.dev', 'opened': true});
    final bad = await _run(BrowserOpenTool(opener: opener), {
      'url': 'http://x.com',
    });
    expect(bad.error!.code, ClientToolErrorCode.invalidArguments);
  });

  final maps = NexaAppTarget(
    id: 'google_maps',
    name: 'Google Maps',
    iosUri: Uri.parse('comgooglemaps://'),
    androidUri: Uri.parse('https://maps.google.com'),
    fallbackUri: Uri.parse('https://www.google.com/maps'),
  );

  test('app open: allowlist only, app then web fallback', () async {
    final app = await _run(
      AppOpenTool(
        apps: [maps],
        opener: FakeOpener(),
        platform: ClientToolPlatform.ios,
      ),
      {'app_id': 'google_maps'},
    );
    expect(app.output, {'app_id': 'google_maps', 'opened_in': 'app'});

    // iOS custom scheme fails (not installed) → web fallback.
    final web = await _run(
      AppOpenTool(
        apps: [maps],
        opener: _SchemeFails(),
        platform: ClientToolPlatform.ios,
      ),
      {'app_id': 'google_maps'},
    );
    expect(web.output!['opened_in'], 'browser');
    expect(
      AppOpenTool(apps: [maps]).descriptor.inputSchema['properties'],
      containsPair('app_id', {
        'type': 'string',
        'enum': ['google_maps'],
      }),
    );
    expect(
      await AppOpenTool(apps: const []).availability(),
      ClientToolAvailability.disabledByHost,
    );
  });

  test(
    'apps query: allowlist with install status, no background apps',
    () async {
      final r = await _run(
        AppsQueryTool(
          apps: [maps],
          opener: FakeOpener(),
          platform: ClientToolPlatform.ios,
        ),
      );
      expect(r.output!['background_apps'], 'not_available_on_this_os');
      expect((r.output!['apps']! as List).single, {
        'app_id': 'google_maps',
        'name': 'Google Maps',
        'installed': 'yes',
        'web_fallback': true,
      });
    },
  );

  test('share: text/url/attachment, dismissed is cancellation', () async {
    final sheet = _Sheet('shared');
    final tool = ShareTool(
      resolveAttachment: (id) => id == 'att_1' ? '/tmp/a.png' : null,
      sheet: sheet,
    );
    expect((await _run(tool, {'attachment_id': 'att_1'})).output, {
      'status': 'shared',
    });
    expect(sheet.calls.single.$3, ['/tmp/a.png']);
    expect(
      (await _run(tool, {'attachment_id': 'missing'})).error!.code,
      ClientToolErrorCode.invalidArguments,
    );
    final dismissed = await _run(
      ShareTool(resolveAttachment: (_) => null, sheet: _Sheet('dismissed')),
      {'text': 'hi'},
    );
    expect(dismissed.status, ClientToolResultStatus.cancelled);
  });

  test('files: cancel, too large, wrong type, accepted', () async {
    final dir = Directory.systemTemp.createTempSync('nexa_files');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = NexaMediaStore(root: Directory('${dir.path}/m'));
    final pdf = File('${dir.path}/bill.pdf')..writeAsBytesSync([1, 2, 3]);
    Future<ClientToolResult> pick(PickedFile? f) =>
        _run(FilesPickTool(media: store, picker: _Picker(f)));
    expect((await pick(null)).status, ClientToolResultStatus.cancelled);
    expect(
      (await pick((
        path: pdf.path,
        name: 'big.pdf',
        size: 20 << 20,
      ))).error!.code,
      ClientToolErrorCode.fileTooLarge,
    );
    expect(
      (await pick((path: pdf.path, name: 'x.exe', size: 3))).error!.code,
      ClientToolErrorCode.fileTypeUnsupported,
    );
    final ok = await pick((path: pdf.path, name: 'bill.pdf', size: 3));
    final att = ok.output!['attachment']! as Map;
    expect(att['name'], 'bill.pdf');
    expect(att['mime_type'], 'application/pdf');
    expect(att.containsKey('local_path'), isFalse);
  });

  test('settings: app page', () async {
    final r = await _run(SettingsOpenTool(location: FakeLocation()), {
      'target': 'app',
    });
    expect(r.output, {'opened': true, 'target': 'app'});
  });

  test('registry: platform filter, timeout, cancel, advertise', () async {
    final reg = ClientToolRegistry(platform: ClientToolPlatform.ios)
      ..register(NetworkStatusTool(network: _Net(['wifi'])))
      ..register(_Slow());
    final ads = await reg.advertise();
    expect(ads.map((a) => a['id']), contains('device.network.get_status'));
    expect(ads.map((a) => a['id']), isNot(contains('test.android_only')));
    final unsupported = await reg.run(
      _req('test.android_only'),
      approve: (_, _) async => true,
    );
    expect(unsupported.error!.code, ClientToolErrorCode.unsupported);

    final reg2 = ClientToolRegistry()..register(_Slow());
    final timedOut = await reg2.run(
      _req('test.android_only'),
      approve: (_, _) async => true,
    );
    expect(timedOut.error!.code, ClientToolErrorCode.timeout);

    final reg3 = ClientToolRegistry()
      ..register(_Slow(timeout: const Duration(seconds: 5)));
    final pending = reg3.run(
      _req('test.android_only'),
      approve: (_, _) async => true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(reg3.cancel('c'), isTrue);
    final cancelled = await pending;
    expect(cancelled.error!.code, ClientToolErrorCode.cancelled);
    expect(cancelled.toolId, 'test.android_only');
  });
}

final class _SchemeFails implements UrlOpener {
  @override
  Future<bool> openInApp(Uri uri) async => false;
  @override
  Future<bool> openInBrowser(Uri uri) async => uri.scheme == 'https';
  @override
  Future<bool> canOpen(Uri uri) async => false;
}

final class _Slow implements ClientToolExecutor {
  _Slow({this.timeout = const Duration(milliseconds: 30)});
  final Duration timeout;

  @override
  late final ClientToolDescriptor descriptor = ClientToolDescriptor(
    id: 'test.android_only',
    version: 1,
    title: 'Slow',
    requiresApproval: false,
    platforms: const {ClientToolPlatform.android},
    timeout: timeout,
    inputSchema: const {'type': 'object'},
    outputSchema: const {'type': 'object'},
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return ClientToolResult.success(request, const {});
  }
}
