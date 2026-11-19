// labeeb.sdk/1 end to end: the SDK's real HTTP client and tool-call
// controller against the local reference gateway over real sockets.
//
// The reference gateway is development infrastructure that implements the
// AWS-published contract (docs/contracts/labeeb-sdk-1/) with scripted tool
// selection and sample data. Passing here proves the client's requests,
// state handling and recovery; it is NOT a production result.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_reference_gateway/nexa_reference_gateway.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';

import '../helpers.dart';
import 'reference_auth_provider.dart';

final class _Location implements LocationPlatform {
  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermissionState> permission() async =>
      LocationPermissionState.granted;
  @override
  Future<LocationPermissionState> requestPermission() async =>
      LocationPermissionState.granted;
  @override
  Future<LocationFix> currentFix({
    required bool highAccuracy,
    required Duration timeout,
  }) async => LocationFix(
    latitude: 33.3152,
    longitude: 44.3661,
    accuracyMeters: 9,
    timestamp: DateTime.now().toUtc(),
  );
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

final class _Opener implements UrlOpener {
  final List<Uri> opened = [];
  @override
  Future<bool> canOpen(Uri uri) async => true;
  @override
  Future<bool> openInApp(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<bool> openInBrowser(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

final class _Theme extends ChangeNotifier implements NexaHostThemeController {
  NexaThemeSpec? previewed;
  NexaThemeSpec? applied;
  @override
  List<NexaThemeOption> get palettes => const [];
  @override
  String get appliedPaletteId => applied?.paletteId ?? 'original';
  @override
  NexaAppearance get appliedAppearance =>
      applied?.appearance ?? NexaAppearance.system;
  @override
  Future<bool> preview(String p, NexaAppearance a) async => true;
  @override
  Future<bool> cancelPreview() async => true;
  @override
  Future<bool> apply(String p, NexaAppearance a) async => true;
  @override
  Future<bool> reset() async {
    applied = null;
    return true;
  }

  @override
  Future<bool> previewSpec(NexaThemeSpec spec) async {
    previewed = spec;
    return true;
  }

  @override
  Future<bool> applySpec(NexaThemeSpec spec) async {
    applied = spec;
    return true;
  }
}

void main() {
  late ReferenceGateway gw;
  late _Opener opener;
  late _Theme theme;
  NexaClient? client;

  setUpAll(() => HttpOverrides.global = null);

  setUp(() async {
    gw = await ReferenceGateway.start(
      port: 0,
      options: const GatewayOptions(
        deltaDelay: Duration(milliseconds: 2),
        thinkDelay: Duration(milliseconds: 10),
        keepAliveInterval: Duration(milliseconds: 500),
        clientToolTimeout: Duration(seconds: 5),
      ),
    );
    opener = _Opener();
    theme = _Theme();
  });

  tearDown(() async {
    await client?.dispose();
    client = null;
    await gw.close();
  });

  Future<(NexaClient, ChatBloc)> start() async {
    final c = await Nexa.initialize(
      config: testConfig(gateway: gw.uri),
      auth: ReferenceAuthProvider(gw.uri),
      host: NexaHostCapabilities(theme: theme),
      clientTools: NexaClientToolOptions(
        locationPlatform: _Location(),
        urlOpener: opener,
      ),
    );
    client = c;
    final bloc = c.injector<ChatBloc>()..add(const ChatStarted());
    await waitFor(
      () => bloc.state.conversation.phase == ConversationPhase.active,
    );
    final tc = c.toolCalls
      ..chatSession = (() => bloc.sessionId?.value)
      ..conversation = (() => bloc.conversationId)
      ..uiEventSink = bloc.sendUiEvent;
    bloc.toolEvents.listen(tc.ingest);
    return (c, bloc);
  }

  LabeebToolActivity? call(NexaClient c, String tool) =>
      c.toolCalls.activities.where((a) => a.call.tool == tool).lastOrNull;

  Future<LabeebToolActivity> waitCall(
    NexaClient c,
    String tool,
    bool Function(LabeebToolActivity) ok,
  ) async {
    await waitFor(
      () => call(c, tool) != null && ok(call(c, tool)!),
      reason: '$tool state',
    );
    return call(c, tool)!;
  }

  test(
    'session joins a server conversation and declares device tools',
    () async {
      final (c, bloc) = await start();
      expect(bloc.conversationId, startsWith('conv_'));
      final s = gw.store.sessions[bloc.sessionId!.value]!;
      expect(s.conversationId, bloc.conversationId);
      expect(
        s.clientTools,
        containsAll([
          'device.location.get_current',
          'maps.open_directions',
          'browser.open_url',
          'app.theme.apply',
          'device.microphone.record_sample',
        ]),
      );
      expect(s.clientTools.length, lessThanOrEqualTo(8));
      final catalogue = await c.api.tools();
      expect(catalogue.enabled, isTrue);
      expect(
        catalogue['sports.matches']!.unavailableReason,
        'requires_configuration',
      );
    },
  );

  test(
    'places: approval → location → places + nexa.ui/1 → select → maps',
    () async {
      final (c, bloc) = await start();
      bloc.add(const ChatMessageSent('restaurants near me'));
      var loc = await waitCall(
        c,
        LabeebTools.location,
        (a) => a.phase == LabeebLocalPhase.awaitingUser,
      );
      expect(loc.call.status, NexaToolCallStatus.awaitingApproval);
      await c.toolCalls.decide(loc.call.id, allow: true);
      loc = await waitCall(
        c,
        LabeebTools.location,
        (a) => a.call.status == NexaToolCallStatus.succeeded,
      );
      final places = await waitCall(
        c,
        LabeebTools.placesNearby,
        (a) => a.call.status == NexaToolCallStatus.succeeded,
      );
      expect((places.call.result!['places']! as List), hasLength(3));
      await waitFor(
        () => c.media.items.whereType<NexaUiDocumentItem>().isNotEmpty,
      );
      final doc = c.toolCalls.document(
        c.media.items.whereType<NexaUiDocumentItem>().last.uiId,
      )!;
      expect(doc.category, 'places_maps');
      final choice = doc.nodes.firstWhere((n) => n.type == 'choice');
      expect(choice.optionByOrdinal(2)!.id, 'pl_ref_2');

      // Touch the second place: same id the voice "second one" would use.
      await waitFor(() => !bloc.state.conversation.isAssistantResponding);
      final refused = await c.toolCalls.sendUiEvent(
        NexaUiEvent(
          uiId: doc.id,
          componentId: choice.id,
          event: 'select',
          optionIds: [choice.optionByOrdinal(2)!.id],
        ),
      );
      expect(refused, isNull);
      final maps = await waitCall(
        c,
        LabeebTools.directions,
        (a) => a.phase == LabeebLocalPhase.awaitingUser,
      );
      expect(
        (maps.call.arguments['destination']! as Map)['place_id'],
        'pl_ref_2',
      );
      await c.toolCalls.decide(maps.call.id, allow: true);
      await waitCall(
        c,
        LabeebTools.directions,
        (a) => a.call.status == NexaToolCallStatus.succeeded,
      );
      expect(opener.opened.single.queryParameters['destination'], isNotNull);
    },
  );

  test('a forged ui_event answers unknown_ui_component', () async {
    final (c, _) = await start();
    final code = await c.toolCalls.sendUiEvent(
      const NexaUiEvent(uiId: 'ui_forged', componentId: 'x', event: 'select'),
    );
    expect(code, 'unknown_ui_component');
  });

  test('deny: the call ends denied and nothing runs', () async {
    final (c, bloc) = await start();
    bloc.add(const ChatMessageSent('where am i'));
    final loc = await waitCall(
      c,
      LabeebTools.location,
      (a) => a.phase == LabeebLocalPhase.awaitingUser,
    );
    await c.toolCalls.decide(loc.call.id, allow: false);
    await waitCall(
      c,
      LabeebTools.location,
      (a) => a.call.status == NexaToolCallStatus.denied,
    );
    await waitFor(
      () => bloc.state.conversation.messages.last.text.contains("won't"),
    );
  });

  test('theme: palettes document → select → preview → apply → prefs', () async {
    final (c, bloc) = await start();
    bloc.add(const ChatMessageSent('change the app colors'));
    await waitFor(
      () => c.media.items.whereType<NexaUiDocumentItem>().isNotEmpty,
    );
    final doc = c.toolCalls.document(
      c.media.items.whereType<NexaUiDocumentItem>().last.uiId,
    )!;
    expect(doc.category, 'themes_appearance');
    expect(doc.presentation, NexaUiPresentation.bottomSheet);
    final palette = doc.nodes.firstWhere((n) => n.type == 'palette');
    expect(palette.options.map((o) => o.id), contains('blue'));
    await waitFor(() => !bloc.state.conversation.isAssistantResponding);
    await c.toolCalls.sendUiEvent(
      NexaUiEvent(
        uiId: doc.id,
        componentId: palette.id,
        event: 'select',
        optionIds: const ['blue'],
      ),
    );
    final apply = await waitCall(
      c,
      LabeebTools.themeApply,
      (a) => a.phase == LabeebLocalPhase.awaitingUser,
    );
    expect(theme.previewed?.paletteId, 'blue', reason: 'preview first');
    expect(theme.applied, isNull);
    await c.toolCalls.decide(apply.call.id, allow: true);
    final done = await waitCall(
      c,
      LabeebTools.themeApply,
      (a) => a.call.status == NexaToolCallStatus.succeeded,
    );
    expect(done.call.result!['status'], 'applied');
    expect(theme.applied?.colors['primary'], const Color(0xFF1565C0));
    await waitFor(() => gw.store.preferences.isNotEmpty);
    expect(gw.store.preferences.values.single['theme.palette_id'], 'blue');
  });

  test(
    'image job: running → progress → asset → completed (placeholder)',
    () async {
      final (c, bloc) = await start();
      bloc.add(const ChatMessageSent('generate an image of a cat'));
      final job = await waitCall(
        c,
        LabeebTools.imageGenerate,
        (a) => a.call.status == NexaToolCallStatus.running,
      );
      expect(job.call.asynchronous, isTrue);
      await waitCall(c, LabeebTools.imageGenerate, (a) => a.progress != null);
      final done = await waitCall(
        c,
        LabeebTools.imageGenerate,
        (a) => a.call.status == NexaToolCallStatus.succeeded,
      );
      expect(done.assets.single.generated, isTrue);
      final bytes = await c.toolCalls.assetBytes(done.assets.single.id);
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    },
  );

  test('image job can be stopped', () async {
    final (c, bloc) = await start();
    bloc.add(const ChatMessageSent('generate an image of a dog'));
    final job = await waitCall(
      c,
      LabeebTools.imageGenerate,
      (a) => a.call.status == NexaToolCallStatus.running,
    );
    expect(await c.toolCalls.cancel(job.call.id), isNull);
    await waitCall(
      c,
      LabeebTools.imageGenerate,
      (a) => a.call.status == NexaToolCallStatus.cancelled,
    );
  });

  test('news: provider blocked arrives as an honest failure', () async {
    final (c, bloc) = await start();
    bloc.add(const ChatMessageSent('latest news'));
    final news = await waitCall(
      c,
      LabeebTools.news,
      (a) => a.call.status.terminal,
    );
    expect(news.call.status, NexaToolCallStatus.failed);
    expect(news.call.error!.code, 'provider_rate_limited');
  });

  test('history: list, open, rename, delete through the server', () async {
    final (c, bloc) = await start();
    bloc.add(const ChatMessageSent('hello history'));
    await waitFor(() {
      final m = bloc.state.conversation.messages;
      return m.length >= 2 && !m.last.isInProgress;
    });
    final api = LabeebConversationsApi(c.api);
    final page = await api.list();
    final entry = page.items.singleWhere((e) => e.id == bloc.conversationId);
    expect(entry.title, 'hello history');
    final messages = await api.open(entry.id);
    expect(messages.first.text, 'hello history');
    expect(messages.first.fromUser, isTrue);
    expect(messages.last.fromUser, isFalse);
    await api.rename(entry.id, 'Renamed');
    expect((await c.api.conversation(entry.id)).title, 'Renamed');
    await api.delete(NexaDeletionScope.conversation, conversationId: entry.id);
    expect(
      () => c.api.conversation(entry.id),
      throwsA(
        isA<NexaException>().having(
          gatewayErrorCode,
          'code',
          'conversation_not_found',
        ),
      ),
    );
  });

  test('attachments: upload, send with a message, read back', () async {
    final (c, bloc) = await start();
    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];
    final asset = await c.api.uploadAsset(
      bloc.conversationId!,
      Uint8List.fromList(png),
      mime: 'image/png',
      filename: 'x.png',
    );
    expect(asset.isImage, isTrue);
    bloc.add(ChatMessageSent('what is in this', attachments: [asset.id]));
    await waitFor(() {
      final m = bloc.state.conversation.messages;
      return m.length >= 2 && !m.last.isInProgress;
    });
    final msgs = await c.api.messages(bloc.conversationId!);
    final parts = msgs.items.first.parts;
    expect(parts.any((p) => p['asset_id'] == asset.id), isTrue);
    expect(await c.api.assetContent(asset.id), png);
    // Wrong bytes for the declared type are refused.
    expect(
      () => c.api.uploadAsset(
        bloc.conversationId!,
        Uint8List.fromList([1, 2, 3, 4, 5]),
        mime: 'image/png',
      ),
      throwsA(
        isA<NexaException>().having(
          gatewayErrorCode,
          'code',
          'unsupported_media_type',
        ),
      ),
    );
  });
}
