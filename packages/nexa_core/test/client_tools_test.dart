import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

final class _Fake implements ClientToolExecutor {
  int runs = 0;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: 'device.test',
    version: 1,
    title: 'Test',
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['n'],
      'properties': {
        'n': {'type': 'integer', 'minimum': 1, 'maximum': 3},
        'mode': {
          'type': 'string',
          'enum': ['a', 'b'],
        },
      },
    },
    outputSchema: {'type': 'object'},
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    runs++;
    return ClientToolResult.success(request, {'ok': true});
  }
}

ClientToolRequest _req({
  String tool = 'device.test',
  int version = 1,
  Map<String, Object?> args = const {'n': 2},
  ClientToolOrigin origin = ClientToolOrigin.user,
}) => ClientToolRequest(
  callId: 'c1',
  toolId: tool,
  version: version,
  arguments: args,
  origin: origin,
);

void main() {
  group('serialization', () {
    test('request round-trips and rejects malformed payloads', () {
      final json = {
        'contract': clientToolContractV1,
        'call_id': 'call_1',
        'tool_id': 'device.location.get_current',
        'tool_version': 1,
        'arguments': {'accuracy': 'high'},
        'session_id': 'ses_1',
        'expires_at': '2026-10-28T10:00:00Z',
      };
      final r = ClientToolRequest.fromJson(json);
      expect(r.callId, 'call_1');
      expect(r.arguments['accuracy'], 'high');
      expect(r.toJson()['contract'], clientToolContractV1);
      expect(
        () => ClientToolRequest.fromJson({...json, 'contract': 'x'}),
        throwsFormatException,
      );
      expect(
        () => ClientToolRequest.fromJson({...json}..remove('call_id')),
        throwsFormatException,
      );
      expect(
        () => ClientToolRequest.fromJson({...json, 'arguments': 'rm -rf'}),
        throwsFormatException,
      );
    });

    test('result uses snake_case error codes and round-trips', () {
      final r = ClientToolResult.failure(
        _req(),
        const ClientToolError(
          ClientToolErrorCode.permissionBlocked,
          'blocked',
          canOpenSettings: true,
        ),
      );
      final json = r.toJson();
      expect((json['error']! as Map)['code'], 'permission_blocked');
      final back = ClientToolResult.fromJson(json);
      expect(back.error!.code, ClientToolErrorCode.permissionBlocked);
      expect(back.error!.canOpenSettings, isTrue);
      expect(back.status, ClientToolResultStatus.failed);
    });
  });

  group('registry', () {
    late _Fake tool;
    late ClientToolRegistry registry;
    setUp(() {
      tool = _Fake();
      registry = ClientToolRegistry()..register(tool);
    });

    Future<ClientToolResult> run(ClientToolRequest r, {bool approve = true}) =>
        registry.run(r, approve: (_, _) async => approve);

    test('unknown / model-invented tool ids never execute', () async {
      final r = await run(_req(tool: 'shell.exec'));
      expect(r.error!.code, ClientToolErrorCode.unknownTool);
      expect(tool.runs, 0);
    });

    test('version, arguments and host enablement are enforced', () async {
      expect(
        (await run(_req(version: 2))).error!.code,
        ClientToolErrorCode.unsupportedVersion,
      );
      expect(
        (await run(_req(args: {'n': 9}))).error!.code,
        ClientToolErrorCode.invalidArguments,
      );
      expect(
        (await run(_req(args: {'n': 1, 'extra': 1}))).error!.code,
        ClientToolErrorCode.invalidArguments,
      );
      expect(
        (await run(_req(args: {'n': 1, 'mode': 'z'}))).error!.code,
        ClientToolErrorCode.invalidArguments,
      );
      expect(
        (await run(_req(args: {}))).error!.code,
        ClientToolErrorCode.invalidArguments,
      );
      final off = ClientToolRegistry(enabledToolIds: {})..register(_Fake());
      final r = await off.run(_req(), approve: (_, _) async => true);
      expect(r.error!.code, ClientToolErrorCode.disabledByHost);
      expect(tool.runs, 0);
    });

    test('assistant requests need toolCalling granted', () async {
      final denied = await run(_req(origin: ClientToolOrigin.assistant));
      expect(denied.error!.code, ClientToolErrorCode.notGranted);
      registry.grantedCapabilities = {NexaCapability.toolCalling};
      final ok = await run(_req(origin: ClientToolOrigin.assistant));
      expect(ok.isSuccess, isTrue);
    });

    test('declining is a cancelled result; success reports phases', () async {
      final declined = await run(_req(), approve: false);
      expect(declined.status, ClientToolResultStatus.cancelled);
      expect(tool.runs, 0);
      final phases = <ClientToolRunPhase>[];
      final ok = await registry.run(
        _req(),
        approve: (_, _) async => true,
        onPhase: phases.add,
      );
      expect(ok.output, {'ok': true});
      expect(phases, [
        ClientToolRunPhase.requested,
        ClientToolRunPhase.awaitingApproval,
        ClientToolRunPhase.running,
        ClientToolRunPhase.succeeded,
      ]);
    });

    test('expired requests are rejected', () async {
      final r = await registry.run(
        ClientToolRequest(
          callId: 'c',
          toolId: 'device.test',
          version: 1,
          arguments: const {'n': 1},
          origin: ClientToolOrigin.user,
          expiresAt: DateTime.utc(2020),
        ),
        approve: (_, _) async => true,
      );
      expect(r.error!.code, ClientToolErrorCode.expired);
    });
  });

  group('places', () {
    Map<String, Object?> result(List<Object?> places, {String status = 'ok'}) =>
        {
          'contract': placesContractV1,
          'result_id': 'r1',
          'status': status,
          'places': places,
        };
    Map<String, Object?> place(String id, String name) => {
      'place_id': id,
      'name': name,
      'location': {'lat': 33.3, 'lng': 44.4},
      'rating': 4.2,
      'distance_m': 420,
    };

    test('parses places, skips invalid ones, keeps ordinals', () {
      final r = NexaPlacesResult.fromJson(
        result([
          place('ChIJ_first_000001', 'First'),
          {
            'name': 'no id',
            'location': {'lat': 1, 'lng': 2},
          },
          {
            'place_id': 'x',
            'name': 'bad',
            'location': {'lat': 200, 'lng': 0},
          },
          place('ChIJ_second_00002', 'Second'),
        ]),
      );
      expect(r.places.map((p) => p.name), ['First', 'Second']);
      final item = NexaPlacesItem(
        id: 'i',
        createdAt: DateTime.utc(2026),
        result: r,
      );
      expect(item.placeAt(2)!.placeId, 'ChIJ_second_00002');
      expect(item.placeAt(3), isNull);
      expect(item.ordinals.last, {
        'ordinal': 2,
        'place_id': 'ChIJ_second_00002',
        'name': 'Second',
      });
    });

    test('ok without valid places is zero results; bad envelope throws', () {
      expect(
        NexaPlacesResult.fromJson(result([])).status,
        NexaPlacesStatus.zeroResults,
      );
      expect(
        NexaPlacesResult.fromJson(result([], status: 'location_denied')).status,
        NexaPlacesStatus.locationDenied,
      );
      expect(
        () => NexaPlacesResult.fromJson({...result([]), 'status': 'maybe'}),
        throwsFormatException,
      );
    });
  });
}
