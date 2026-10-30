import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// In-memory host theme: what a host app implements.
final class _FakeTheme extends ChangeNotifier
    implements NexaHostThemeController {
  String palette = 'pal_a';
  NexaAppearance appearance = NexaAppearance.system;
  (String, NexaAppearance)? previewing;
  int saves = 0;

  @override
  List<NexaThemeOption> get palettes => const [
    NexaThemeOption(
      id: 'pal_a',
      label: 'Alpha',
      localizedLabels: {'ar': 'ألفا'},
      swatches: [Color(0xFF7B5A49)],
    ),
    NexaThemeOption(
      id: 'pal_b',
      label: 'Beta',
      localizedLabels: {'ar': 'بيتا'},
      swatches: [Color(0xFFA8322D)],
    ),
  ];
  @override
  String get appliedPaletteId => palette;
  @override
  NexaAppearance get appliedAppearance => appearance;

  bool _known(String id) => palettes.any((p) => p.id == id);

  @override
  Future<bool> preview(String id, NexaAppearance a) async {
    if (!_known(id)) return false;
    previewing = (id, a);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> cancelPreview() async {
    previewing = null;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> apply(String id, NexaAppearance a) async {
    if (!_known(id)) return false;
    palette = id;
    appearance = a;
    previewing = null;
    saves++;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> reset() => apply('pal_a', NexaAppearance.system);

  NexaThemeSpec? lastSpec;

  @override
  Future<bool> previewSpec(NexaThemeSpec spec) async {
    lastSpec = spec;
    return preview(
      _known(spec.paletteId) ? spec.paletteId : 'pal_a',
      spec.appearance,
    );
  }

  @override
  Future<bool> applySpec(NexaThemeSpec spec) async {
    lastSpec = spec;
    palette = spec.paletteId;
    appearance = spec.appearance;
    previewing = null;
    saves++;
    notifyListeners();
    return true;
  }
}

Map<String, Object?> _surface({
  String id = 'srf_1',
  String version = '1.0',
  String category = 'news',
  Map<String, Object?> status = const {'state': 'ready'},
  List<Map<String, Object?>> components = const [],
  List<Map<String, Object?>> actions = const [],
  bool demo = false,
}) => {
  'schema_version': version,
  'surface_id': id,
  'category': category,
  'title': 'Title $id',
  'fallback_text': 'Fallback $id',
  'status': status,
  'components': components,
  'actions': actions,
  'demo': demo,
};

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: NexaLocale.supported,
  localizationsDelegates: NexaLocale.delegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('parseNexaSurface', () {
    test('valid surface keeps ids, category, presentation, components', () {
      final s = parseNexaSurface({
        ..._surface(
          components: [
            {
              'type': 'single_choice',
              'id': 'c1',
              'choices': [
                {'id': 'x', 'label': 'X'},
                {'id': 'y', 'label': 'Y', 'order': 7},
              ],
            },
          ],
        ),
        'presentation': 'bottom_sheet',
        'conversation_id': 'conv_1',
        'message_id': 'msg_1',
      })!;
      expect(s.surfaceId, 'srf_1');
      expect(s.supported, isTrue);
      expect(s.category, NexaSurfaceCategory.news);
      expect(s.presentation, NexaPresentation.bottomSheet);
      expect(s.conversationId, 'conv_1');
      expect(s.messageId, 'msg_1');
      expect([for (final c in s.components.single.choices) c.order], [1, 7]);
    });

    test('missing surface_id is rejected', () {
      expect(parseNexaSurface({'schema_version': '1.0'}), isNull);
    });

    test('unsupported major version renders only fallback text', () {
      final s = parseNexaSurface(_surface(version: '2.0'))!;
      expect(s.supported, isFalse);
      expect(s.fallbackText, 'Fallback srf_1');
    });

    test('unknown component and action types are kept but not trusted', () {
      final s = parseNexaSurface(
        _surface(
          components: [
            {'type': 'html_blob', 'id': 'c1', 'text': 'shown as text'},
          ],
          actions: [
            {'id': 'a1', 'type': 'shell.exec'},
          ],
        ),
      )!;
      expect(s.components.single.known, isFalse);
      expect(s.actions.single.known, isFalse);
    });

    test('status maps provider_unavailable and unknown presentation', () {
      final s = parseNexaSurface({
        ..._surface(status: {'state': 'error', 'code': 'provider_unavailable'}),
        'presentation': 'hologram',
      })!;
      expect(s.status.state, NexaSurfaceState.providerUnavailable);
      expect(s.presentation, NexaPresentation.inlineCard);
    });

    test('selection event serialises the wire shape', () {
      final json = const NexaSurfaceEvent(
        eventType: 'selection',
        surfaceId: 'srf_1',
        componentId: 'c1',
        choiceIds: ['y'],
        source: NexaSelectionSource.voice,
        utterance: 'the second one',
      ).toJson();
      expect(json['surface_id'], 'srf_1');
      expect(json['choice_ids'], ['y']);
      expect(json['source'], 'voice');
    });
  });

  group('renderer', () {
    Future<NexaSurfaceController> pump(
      WidgetTester tester,
      Map<String, Object?> json, {
      NexaHostCapabilities host = const NexaHostCapabilities(),
      Locale locale = const Locale('en'),
    }) async {
      final c = NexaSurfaceController(host: host)
        ..upsert(parseNexaSurface(json)!);
      await tester.pumpWidget(
        _app(
          NexaSurfaceCard(
            surfaceId: json['surface_id']! as String,
            controller: c,
          ),
          locale: locale,
        ),
      );
      await tester.pump();
      return c;
    }

    for (final (state, key) in [
      ('loading', 'nexa_surface_loading'),
      ('empty', 'nexa_surface_empty'),
      ('offline', 'nexa_surface_offline'),
    ]) {
      testWidgets('state $state', (tester) async {
        await pump(tester, _surface(status: {'state': state}));
        expect(find.byKey(Key(key)), findsOneWidget);
      });
    }

    testWidgets('error with retry and provider unavailable', (tester) async {
      await pump(
        tester,
        _surface(status: {'state': 'error', 'retryable': true}),
      );
      expect(find.byKey(const Key('nexa_surface_error')), findsOneWidget);
      await pump(
        tester,
        _surface(status: {'state': 'error', 'code': 'provider_unavailable'}),
      );
      expect(
        find.byKey(const Key('nexa_surface_provider_unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('unsupported schema shows fallback only', (tester) async {
      await pump(tester, _surface(version: '3.1'));
      expect(find.byKey(const Key('nexa_surface_unsupported')), findsOneWidget);
      expect(find.text('Fallback srf_1'), findsOneWidget);
    });

    testWidgets('unknown component: its fallback text, never its payload', (
      tester,
    ) async {
      await pump(
        tester,
        _surface(
          components: [
            {
              'type': 'html_blob',
              'id': 'c1',
              'html': '<script>x()</script>',
              'fallback_text': 'Plain fallback',
            },
          ],
        ),
      );
      expect(find.text('Plain fallback'), findsOneWidget);
      expect(find.textContaining('<script>'), findsNothing);
    });

    testWidgets('demo surfaces are labelled', (tester) async {
      await pump(tester, _surface(demo: true));
      expect(find.byKey(const Key('nexa_surface_demo')), findsOneWidget);
    });

    testWidgets('selection emits event; update keeps valid selection', (
      tester,
    ) async {
      Map<String, Object?> json(List<String> ids) => _surface(
        components: [
          {
            'type': 'single_choice',
            'id': 'c1',
            'choices': [
              for (final id in ids) {'id': id, 'label': id.toUpperCase()},
            ],
          },
        ],
      );
      final c = await pump(tester, json(['x', 'y']));
      final events = <NexaSurfaceEvent>[];
      c.events.listen(events.add);
      await tester.tap(find.byKey(const Key('nexa_choice_c1_y')));
      await tester.pump();
      expect(events.single.choiceIds, ['y']);
      expect(c.value('srf_1', 'c1'), 'y');
      c.upsert(parseNexaSurface(json(['x', 'y', 'z']))!);
      expect(c.value('srf_1', 'c1'), 'y');
      c.upsert(parseNexaSurface(json(['x']))!);
      expect(c.value('srf_1', 'c1'), isNull);
    });

    testWidgets('RTL: Arabic surface lays out right-to-left', (tester) async {
      await pump(
        tester,
        _surface(
          components: [
            {'type': 'text', 'id': 't', 'text': 'مرحبا'},
          ],
        ),
        locale: const Locale('ar'),
      );
      final dir = Directionality.of(
        tester.element(find.byKey(const Key('nexa_surface_srf_1'))),
      );
      expect(dir, TextDirection.rtl);
    });
  });

  group('host theme', () {
    testWidgets('no host theme: picker surface shows Unavailable', (
      tester,
    ) async {
      final c = NexaSurfaceController()
        ..upsert(
          parseNexaSurface(
            _surface(id: 'srf_t', category: 'themes_appearance'),
          )!,
        );
      await tester.pumpWidget(
        _app(NexaSurfaceCard(surfaceId: 'srf_t', controller: c)),
      );
      expect(
        find.byKey(const Key('nexa_surface_host_unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('select previews, cancel restores, apply persists, reset', (
      tester,
    ) async {
      final theme = _FakeTheme();
      final c = NexaSurfaceController(host: NexaHostCapabilities(theme: theme))
        ..upsert(buildThemeSurface(theme, languageCode: 'en'));
      await tester.pumpWidget(
        _app(NexaSurfaceCard(surfaceId: 'srf_theme_local', controller: c)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('nexa_palette_pal_b')));
      await tester.pump();
      expect(theme.previewing, ('pal_b', NexaAppearance.system));
      expect(theme.palette, 'pal_a', reason: 'preview must not commit');

      await tester.tap(find.byKey(const Key('nexa_action_a_cancel')).first);
      await tester.pumpAndSettle();
      expect(theme.previewing, isNull);
      expect(theme.saves, 0);

      await tester.tap(find.byKey(const Key('nexa_palette_pal_b')));
      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('nexa_action_a_apply')).first);
      await tester.pumpAndSettle();
      // Apply asks first.
      await tester.tap(find.byKey(const Key('nexa_surface_confirm_ok')));
      await tester.pumpAndSettle();
      expect(theme.palette, 'pal_b');
      expect(theme.appearance, NexaAppearance.dark);
      expect(theme.saves, 1);

      await tester.tap(find.byKey(const Key('nexa_action_a_reset')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nexa_surface_confirm_ok')));
      await tester.pumpAndSettle();
      expect(theme.palette, 'pal_a');
      expect(theme.appearance, NexaAppearance.system);
      expect(c.value('srf_theme_local', 'c_palette'), 'pal_a');
    });

    testWidgets('palette swatches are painted (non-zero size)', (tester) async {
      final theme = _FakeTheme();
      final c = NexaSurfaceController(host: NexaHostCapabilities(theme: theme))
        ..upsert(buildThemeSurface(theme, languageCode: 'en'));
      await tester.pumpWidget(
        _app(NexaSurfaceCard(surfaceId: 'srf_theme_local', controller: c)),
      );
      final swatch = find.descendant(
        of: find.byKey(const Key('nexa_palette_pal_b')),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == const Color(0xFFA8322D),
        ),
      );
      expect(swatch, findsOneWidget);
      expect(tester.getSize(swatch).height, 36);
    });

    test(
      'host.theme tools: unknown palette refused, apply reports state',
      () async {
        final theme = _FakeTheme();
        final tools = {
          for (final t in HostThemeTool.forHost(theme)) t.descriptor.id: t,
        };
        expect(tools.keys, {
          HostThemeTool.previewId,
          HostThemeTool.applyId,
          HostThemeTool.resetId,
        });
        expect(
          tools[HostThemeTool.applyId]!.descriptor.requiresApproval,
          isTrue,
        );
        expect(
          tools[HostThemeTool.previewId]!.descriptor.requiresApproval,
          isFalse,
        );
        expect(await theme.preview('pal_zzz', NexaAppearance.dark), isFalse);
      },
    );
  });

  group('voice companion', () {
    testWidgets('minimize / expand keeps the surface; dismiss calls back', (
      tester,
    ) async {
      final c = NexaSurfaceController()
        ..upsert(
          parseNexaSurface(
            _surface(
              components: [
                {'type': 'text', 'id': 't', 'text': 'Companion body'},
              ],
            ),
          )!,
        );
      var dismissed = 0;
      await tester.pumpWidget(
        _app(
          NexaSurfaceCompanion(
            surfaceId: 'srf_1',
            controller: c,
            onDismiss: () => dismissed++,
          ),
        ),
      );
      expect(find.text('Companion body'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nexa_companion_toggle')));
      await tester.pump();
      expect(find.text('Companion body'), findsNothing);
      // An update while minimized arrives and is shown on expand.
      c.upsert(
        parseNexaSurface(
          _surface(
            components: [
              {'type': 'text', 'id': 't', 'text': 'Updated body'},
            ],
          ),
        )!,
      );
      await tester.tap(find.byKey(const Key('nexa_companion_toggle')));
      await tester.pump();
      expect(find.text('Updated body'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nexa_companion_dismiss')));
      expect(dismissed, 1);
    });
  });
}
