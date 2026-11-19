import 'dart:async';

import 'package:nexa_reference_gateway/src/png.dart';

import 'package:nexa_reference_gateway/src/store.dart';

/// Deterministic, keyword-driven assistant behaviour. **Not a model.**
///
/// Every scenario is described in the package README. Replies are produced as
/// contract events appended to the session log; delivery (SSE / long-poll) is
/// the server's job.
final class ScriptedResponder {
  ScriptedResponder(this.store);

  final GatewayStore store;

  GatewayOptions get _o => store.options;

  /// Starts the scripted reply for an accepted user message. Returns when the
  /// reply has been fully appended (tests may await it; the server does not).
  Future<void> respond(
    SessionState session, {
    required String userMessageId,
    required String text,
  }) async {
    final lower = text.toLowerCase();
    final ar = session.languageTag == 'ar';

    if (lower.contains('mic')) {
      session.append('permission_requested', {
        'request_id': 'perm_${session.lastSequence + 1}',
        'permission': 'microphone',
        'reason': ar
            ? 'للتحدث مع المساعد نحتاج إلى الميكروفون.'
            : 'Microphone access lets you talk to the assistant.',
      });
    }

    if (lower.contains('quota')) {
      store.application(session.applicationId).quotaRemaining = 0;
      session.append('quota_updated', {
        'quota': {
          'kind': 'messages',
          'remaining': 0,
          'limit': _o.quotaPerApplication,
        },
        'exceeded': true,
      });
    }

    // Stays armed until the next message so poll and SSE behave the same.
    session.chaos.duplicateEvents = lower.contains('duplicate');

    final messageId = session.nextMessageId('assistant');
    final reply = ReplyState(messageId);
    session.replies[messageId] = reply;

    await _delay(_o.thinkDelay);
    if (session.ended) return;
    session.append('assistant_message_started', {
      'message_id': messageId,
      'in_reply_to': userMessageId,
    });

    if (await _clientToolFlow(session, reply, text, lower, ar: ar)) {
      return;
    } else if (lower.contains('weather')) {
      await _weather(session, reply, ar: ar);
    } else if (lower.contains('book') || lower.contains('confirm')) {
      await _booking(session, reply, ar: ar);
      return; // completion happens when the tool action arrives
    } else if (lower.contains('fail')) {
      await _streamWords(
        session,
        reply,
        _words(ar ? 'لحظة من فضلك' : 'One moment please'),
        _o.deltaDelay,
      );
      if (reply.cancelRequested || session.ended) return;
      reply.finished = true;
      session.append('message_failed', {
        'message_id': messageId,
        'error': {
          'code': 'upstream_error',
          'message': 'Scripted upstream failure (reference gateway).',
          'retryable': true,
        },
      });
      return;
    } else {
      final words = _replyWords(text, lower, ar: ar);
      final delay = lower.contains('slow') ? _o.slowDeltaDelay : _o.deltaDelay;
      await _streamWords(session, reply, words, delay);
      if (reply.cancelRequested || session.ended) {
        _finishCancelled(session, reply);
        return;
      }
      reply.finished = true;
      session.append('assistant_message_completed', {
        'message_id': messageId,
        'finish_reason': 'stop',
        'full_text': words.join(' '),
      });
    }

    if (lower.contains('quota')) {
      session.end('quota_exceeded');
    } else if (lower.contains('expire')) {
      session.end('expired');
    }
  }

  /// Called by the server when a tool action arrives for [call].
  Future<void> resolveToolAction(
    SessionState session,
    PendingToolCall call, {
    required String kind,
  }) async {
    call.resolved = true;
    final reply = session.replies[call.messageId]!;
    final ar = session.languageTag == 'ar';
    if (kind == 'confirmed') {
      session.append('tool_execution_progress', {
        'tool_call_id': call.id,
        'status': 'running',
        'progress': 0.5,
      });
      await _delay(_o.thinkDelay);
      session.append('tool_result_received', {
        'tool_call_id': call.id,
        'message_id': call.messageId,
        'result': {
          'kind': 'text',
          'text': ar
              ? 'تم الحجز: طاولة لشخصين الساعة 8 مساءً.'
              : 'Booked: table for two at 8 pm.',
        },
      });
      final words = _words(
        ar ? 'تم تأكيد حجزك.' : 'Your booking is confirmed.',
      );
      await _streamWords(session, reply, words, _o.deltaDelay);
      reply.finished = true;
      session.append('assistant_message_completed', {
        'message_id': call.messageId,
        'finish_reason': 'stop',
        'full_text': words.join(' '),
      });
    } else {
      session.append('tool_execution_progress', {
        'tool_call_id': call.id,
        'status': 'cancelled',
      });
      final words = _words(
        ar ? 'حسناً، لم يتم الحجز.' : 'Okay, nothing was booked.',
      );
      await _streamWords(session, reply, words, _o.deltaDelay);
      reply.finished = true;
      session.append('assistant_message_completed', {
        'message_id': call.messageId,
        'finish_reason': 'stop',
        'full_text': words.join(' '),
      });
    }
  }

  // ------------------------------------------------- labeeb.sdk/1 tools

  /// Contract `theme.palettes` (the server's list, unchanged).
  static const palettes = [
    {
      'id': 'red',
      'label': {'en': 'Red', 'ar': 'أحمر'},
      'colors': {
        'primary': '#C62828',
        'on_primary': '#FFFFFF',
        'secondary': '#FF8A80',
        'surface': '#FFF5F5',
      },
    },
    {
      'id': 'blue',
      'label': {'en': 'Blue', 'ar': 'أزرق'},
      'colors': {
        'primary': '#1565C0',
        'on_primary': '#FFFFFF',
        'secondary': '#82B1FF',
        'surface': '#F3F8FF',
      },
    },
    {
      'id': 'green',
      'label': {'en': 'Green', 'ar': 'أخضر'},
      'colors': {
        'primary': '#2E7D32',
        'on_primary': '#FFFFFF',
        'secondary': '#A5D6A7',
        'surface': '#F4FBF4',
      },
    },
    {
      'id': 'purple',
      'label': {'en': 'Purple', 'ar': 'بنفسجي'},
      'colors': {
        'primary': '#6A1B9A',
        'on_primary': '#FFFFFF',
        'secondary': '#CE93D8',
        'surface': '#FAF5FC',
      },
    },
    {
      'id': 'orange',
      'label': {'en': 'Orange', 'ar': 'برتقالي'},
      'colors': {
        'primary': '#E65100',
        'on_primary': '#FFFFFF',
        'secondary': '#FFCC80',
        'surface': '#FFF8F0',
      },
    },
    {
      'id': 'teal',
      'label': {'en': 'Teal', 'ar': 'فيروزي'},
      'colors': {
        'primary': '#00695C',
        'on_primary': '#FFFFFF',
        'secondary': '#80CBC4',
        'surface': '#F2FAF9',
      },
    },
    {
      'id': 'graphite',
      'label': {'en': 'Graphite', 'ar': 'رمادي فحمي'},
      'colors': {
        'primary': '#37474F',
        'on_primary': '#FFFFFF',
        'secondary': '#B0BEC5',
        'surface': '#F5F7F8',
      },
    },
  ];

  /// Device tools that need the user's approval (contract `tools`).
  static const _needsApproval = {
    'device.location.get_current',
    'device.camera.capture',
    'maps.open_directions',
    'browser.open_url',
    'device.photo.pick',
    'device.file.pick',
    'device.share.content',
    'device.app.open_settings',
    'app.theme.apply',
    'app.theme.reset',
  };

  /// A device tool: requested → (approval) → awaiting_client → result.
  /// Null when the app did not declare it in `client_tools`.
  Future<ContractCall?> _device(
    SessionState session,
    String tool,
    Map<String, Object?> args,
  ) async {
    if (!session.clientTools.contains(tool)) return null;
    final approval = _needsApproval.contains(tool);
    final c = ContractCall(
      id: store.newId('tc'),
      tool: tool,
      side: 'client',
      arguments: args,
      status: approval ? 'awaiting_approval' : 'awaiting_client',
      approvalRequired: approval,
      deadlineAt: DateTime.now().toUtc().add(_o.clientToolTimeout),
    );
    session.contractCalls[c.id] = c;
    session.append('tool_call_requested', c.toJson());
    try {
      await c.done.future.timeout(_o.clientToolTimeout);
    } on TimeoutException {
      if (c.open) {
        c.settle(
          'expired',
          error: {'code': 'deadline_exceeded', 'retryable': true},
        );
        session.append('tool_call_failed', c.toJson());
      }
    }
    return c;
  }

  /// A server tool that answers at once (result or error).
  ContractCall _server(
    SessionState session,
    String tool,
    Map<String, Object?> args, {
    Map<String, Object?>? result,
    Map<String, Object?>? error,
  }) {
    final c = ContractCall(
      id: store.newId('tc'),
      tool: tool,
      side: 'server',
      arguments: args,
      status: 'running',
      deadlineAt: DateTime.now().toUtc().add(const Duration(seconds: 30)),
    );
    session.contractCalls[c.id] = c;
    session.append('tool_call_requested', c.toJson());
    if (error != null) {
      c.settle('failed', error: error);
      session.append('tool_call_failed', c.toJson());
    } else {
      c.settle('succeeded', result: result ?? const {});
      session.append('tool_call_completed', c.toJson());
    }
    return c;
  }

  void _present(
    SessionState session,
    String toolCallId,
    Map<String, Object?> doc,
  ) {
    session.uiDocs[doc['id']! as String] = doc;
    session.append('ui_presented', {'tool_call_id': toolCallId, 'ui': doc});
  }

  static bool _ok(ContractCall? c) => c?.status == 'succeeded';

  /// Scripted stand-in for the AWS orchestrator's tool selection (EN/AR).
  Future<bool> _clientToolFlow(
    SessionState session,
    ReplyState reply,
    String text,
    String lower, {
    required bool ar,
  }) async {
    bool has(List<String> words) => words.any(lower.contains);
    final ordinal = _ordinal(lower);
    if (ordinal != null && has(['take me', 'directions', 'خذني', 'وديني'])) {
      await _directions(session, reply, ordinal, ar: ar);
      return true;
    }
    if (has(['restaurant', 'cafe', 'café', 'مطعم', 'مطاعم', 'مقهى', 'كافيه'])) {
      await _places(
        session,
        reply,
        ar: ar,
        cafes: has(['cafe', 'café', 'مقهى', 'كافيه']),
      );
      return true;
    }
    if (has([
      'reset theme',
      'original colors',
      'original colours',
      'الألوان الأصلية',
      'استعد',
    ])) {
      final c = await _device(session, 'app.theme.reset', const {});
      await _say(session, reply, _deviceText(c, ar));
      return true;
    }
    if (has([
      'theme',
      'colors',
      'colours',
      'color',
      'ألوان',
      'الوان',
      'لون',
      'مظهر',
    ])) {
      final c = _server(
        session,
        'app.theme.list_palettes',
        const {},
        result: {'palettes': palettes},
      );
      _present(session, c.id, {
        'schema': 'nexa.ui/1',
        'id': 'ui_theme_${c.id}',
        'category': 'themes_appearance',
        'presentation': 'bottom_sheet',
        'title': {'en': 'Choose your app colours', 'ar': 'اختر ألوان التطبيق'},
        'root': {
          'id': 'theme_root',
          'type': 'column',
          'children': [
            {
              'id': 'palette',
              'type': 'palette',
              'options': [
                for (final (i, p) in palettes.indexed) {...p, 'ordinal': i + 1},
              ],
              'on_select': {'type': 'send_ui_event', 'event': 'select'},
            },
          ],
        },
      });
      await _say(
        session,
        reply,
        ar
            ? 'اختر لوناً، وسأعرضه قبل التطبيق.'
            : 'Pick a colour and I will preview it before applying.',
      );
      return true;
    }
    if (has(['generate', 'draw', 'image of', 'ارسم', 'أنشئ صورة', 'صورة لـ'])) {
      await _imageJob(session, reply, text, ar: ar);
      return true;
    }
    if (has(['my jobs', 'my tasks', 'job status', 'مهامي'])) {
      final jobs = [
        for (final c in session.contractCalls.values)
          if (c.asynchronous)
            {'job_id': c.id, 'tool': c.tool, 'status': c.status},
      ];
      _server(session, 'jobs.status', const {}, result: {'jobs': jobs});
      await _say(
        session,
        reply,
        jobs.isEmpty
            ? (ar ? 'لا توجد مهام.' : 'You have no tasks.')
            : (ar
                  ? 'لديك ${jobs.length} مهام.'
                  : 'You have ${jobs.length} task(s).'),
      );
      return true;
    }
    if (has(['news', 'أخبار', 'اخبار'])) {
      // Mirrors production today: GDELT throttles the production host.
      _server(
        session,
        'news.search',
        {'query': text},
        error: {
          'code': 'provider_rate_limited',
          'message': 'news provider throttled',
          'retryable': true,
        },
      );
      await _say(
        session,
        reply,
        ar ? 'مصدر الأخبار مشغول الآن.' : 'The news source is busy right now.',
      );
      return true;
    }
    if (has(['score', 'match', 'sports', 'مباراة', 'نتيجة'])) {
      _server(
        session,
        'sports.matches',
        const {'state': 'any'},
        error: {'code': 'requires_configuration', 'retryable': false},
      );
      await _say(
        session,
        reply,
        ar
            ? 'نتائج الرياضة غير مفعّلة بعد.'
            : "Sports results aren't connected yet.",
      );
      return true;
    }
    if (has(['youtube', 'video', 'فيديو'])) {
      _server(
        session,
        'video.search',
        {'query': text},
        error: {'code': 'requires_configuration', 'retryable': false},
      );
      await _say(
        session,
        reply,
        ar
            ? 'البحث عن الفيديو غير مفعّل بعد.'
            : "Video search isn't connected yet.",
      );
      return true;
    }
    if (has(['search', 'wikipedia', 'what is', 'ابحث', 'ما هو', 'ما هي'])) {
      _server(
        session,
        'web.search',
        {'query': text},
        result: {
          'coverage': 'encyclopedia_only',
          'results': [
            {
              'rank': 1,
              'id': 'r_1',
              'title': 'Reference article (sample)',
              'url': 'https://en.wikipedia.org/wiki/Special:Random',
              'source': 'Wikipedia (reference gateway sample)',
            },
          ],
        },
      );
      await _say(
        session,
        reply,
        ar ? 'هذه مقالة مرجعية.' : 'Here is a reference article.',
      );
      return true;
    }
    final String tool;
    final Map<String, Object?> args;
    if (has(['where am i', 'my location', 'وين اني', 'موقعي', 'أين أنا'])) {
      tool = 'device.location.get_current';
      args = {'accuracy': 'fine'};
    } else if (has([
      'camera',
      'show you',
      'take a photo',
      'الكاميرا',
      'اوريك',
    ])) {
      tool = 'device.camera.capture';
      args = {'purpose': ar ? 'لترى ما أريك' : 'to see what you want to show'};
    } else if (has(['gallery', 'photo library', 'choose a photo', 'المعرض'])) {
      tool = 'device.photo.pick';
      args = {'purpose': ar ? 'لاختيار صورة' : 'to look at a photo'};
    } else if (has([
      'website',
      'http',
      'open link',
      'موقع ويب',
      'الموقع الإلكتروني',
    ])) {
      final m = RegExp(r'https://[^\s]+').firstMatch(text);
      tool = 'browser.open_url';
      args = {
        'result_id': 'r_link',
        'url': m?.group(0) ?? 'https://flutter.dev',
      };
    } else if (has([
      'wi-fi',
      'wifi',
      'network',
      'internet',
      'online',
      'واي فاي',
      'الوايفاي',
      'الشبكة',
      'الانترنت',
    ])) {
      tool = 'device.network.get_status';
      args = const {};
    } else if (has(['share', 'شارك'])) {
      tool = 'device.share.content';
      args = {
        'title': 'LABEEB',
        'text': ar ? 'من لبيب' : 'Shared from the assistant',
      };
    } else if (has(['pdf', 'file', 'document', 'ملف'])) {
      final c = await _device(session, 'device.file.pick', {
        'purpose': ar ? 'لقراءة ملف' : 'to read a file',
      });
      if (!_ok(c)) {
        await _say(session, reply, _deviceText(c, ar));
        return true;
      }
      final assetId = c!.result!['asset_id']! as String;
      final asset = store.assets[assetId];
      final readable = asset != null && asset.mime.startsWith('text/');
      _server(
        session,
        'file.read',
        {'asset_id': assetId},
        result: readable
            ? {
                'text': String.fromCharCodes(asset.bytes.take(2000)),
                'truncated': asset.bytes.length > 2000,
              }
            : null,
        error: readable ? null : {'code': 'not_readable', 'retryable': false},
      );
      await _say(
        session,
        reply,
        readable
            ? (ar ? 'قرأت الملف.' : 'I read the file.')
            : (ar
                  ? 'وصل الملف، لكن البوابة المرجعية لا تقرأ هذا النوع.'
                  : "Got the file, but the reference gateway can't read this type."),
      );
      return true;
    } else if (has(['settings', 'الإعدادات', 'الاعدادات'])) {
      tool = 'device.app.open_settings';
      args = {'section': 'app'};
    } else {
      return false;
    }
    final c = await _device(session, tool, args);
    await _say(session, reply, _deviceText(c, ar));
    return true;
  }

  Future<void> _places(
    SessionState session,
    ReplyState reply, {
    required bool ar,
    required bool cafes,
  }) async {
    final loc = await _device(session, 'device.location.get_current', {
      'accuracy': 'fine',
    });
    if (!_ok(loc)) {
      await _say(session, reply, _deviceText(loc, ar));
      return;
    }
    final lat = (loc!.result!['latitude']! as num).toDouble();
    final lng = (loc.result!['longitude']! as num).toDouble();
    final kind = cafes ? (ar ? 'مقهى' : 'Café') : (ar ? 'مطعم' : 'Diner');
    final places = [
      for (var i = 1; i <= 3; i++)
        {
          'rank': i,
          'id': 'pl_ref_$i',
          'name': ar ? '$kind تجريبي $i' : 'Reference $kind $i',
          'rating': 4.0 + i / 10,
          'address': ar ? 'بيانات تجريبية' : 'Sample data',
          'location': {
            'latitude': lat + 0.002 * i,
            'longitude': lng + 0.002 * i,
          },
          'attribution': 'Reference gateway sample data (not a live search)',
        },
    ];
    session.lastPlaces = places;
    final c = _server(
      session,
      'places.search_nearby',
      {
        'included_types': [cafes ? 'cafe' : 'restaurant'],
        'latitude': lat,
        'longitude': lng,
      },
      result: {'places': places},
    );
    _present(session, c.id, {
      'schema': 'nexa.ui/1',
      'id': 'ui_places_${c.id}',
      'category': 'places_maps',
      'presentation': 'inline_card',
      'title': {
        'en': cafes ? 'Cafés near you' : 'Restaurants near you',
        'ar': cafes ? 'مقاهٍ قريبة' : 'مطاعم قريبة',
      },
      'root': {
        'id': 'places_root',
        'type': 'column',
        'children': [
          {
            'id': 'places',
            'type': 'choice',
            'options': [
              for (final p in places)
                {'id': p['id'], 'label': p['name'], 'ordinal': p['rank']},
            ],
            'on_select': {'type': 'send_ui_event', 'event': 'select'},
          },
          {
            'id': 'attr',
            'type': 'text',
            'variant': 'caption',
            'text': 'Reference gateway sample data',
          },
        ],
      },
    });
    await _say(
      session,
      reply,
      ar
          ? 'هذه ثلاثة أماكن قريبة. اختر واحداً أو قل "خذني إلى الثاني".'
          : 'Here are three places nearby. Pick one or say "take me to the second one".',
    );
  }

  Future<void> _directions(
    SessionState session,
    ReplyState reply,
    int ordinal, {
    required bool ar,
  }) async {
    final places = session.lastPlaces;
    final place = ordinal >= 1 && ordinal <= places.length
        ? places[ordinal - 1]
        : null;
    if (place == null) {
      await _say(
        session,
        reply,
        ar ? 'ما عندي قائمة أماكن بعد.' : "I don't have a list of places yet.",
      );
      return;
    }
    final loc = place['location']! as Map;
    final c = await _device(session, 'maps.open_directions', {
      'destination': {
        'place_id': place['id'],
        'latitude': loc['latitude'],
        'longitude': loc['longitude'],
        'name': place['name'],
      },
      'mode': 'driving',
    });
    await _say(
      session,
      reply,
      _ok(c)
          ? (ar
                ? 'فتحت الاتجاهات إلى ${place['name']}.'
                : 'Opened directions to ${place['name']}.')
          : _deviceText(c, ar),
    );
  }

  Future<void> _imageJob(
    SessionState session,
    ReplyState reply,
    String text, {
    required bool ar,
  }) async {
    final c = ContractCall(
      id: store.newId('tc'),
      tool: 'image.generate',
      side: 'server',
      arguments: {'prompt': text},
      status: 'running',
      asynchronous: true,
      deadlineAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    session.contractCalls[c.id] = c;
    session.append('tool_call_requested', c.toJson());
    await _say(
      session,
      reply,
      ar
          ? 'بدأت مهمة الصورة. يمكنك متابعة المحادثة.'
          : 'I started the image job. You can keep chatting.',
    );
    unawaited(() async {
      for (final (i, state) in ['queued', 'reserving', 'running'].indexed) {
        await _delay(_o.thinkDelay * 2);
        if (!c.open || session.ended) return;
        session.append('tool_call_progress', {
          'tool_call_id': c.id,
          'tool': c.tool,
          'state': state,
          'waited_s': (i + 1) * 2,
        });
      }
      await _delay(_o.thinkDelay * 2);
      if (!c.open || session.ended) return;
      final asset = AssetRecord(
        id: store.newId('ast'),
        applicationId: session.applicationId,
        conversationId: session.conversationId ?? '',
        mime: 'image/png',
        bytes: placeholderPng(),
        origin: 'generated',
        filename: 'reference-gateway-placeholder.png',
      );
      store.assets[asset.id] = asset;
      session.append('asset_created', {
        'tool_call_id': c.id,
        'message_id': reply.messageId,
        'asset': {
          'id': asset.id,
          'kind': asset.kind,
          'mime': asset.mime,
          'size_bytes': asset.bytes.length,
          'origin': asset.origin,
        },
      });
      c.settle('succeeded', result: {'asset_id': asset.id});
      session.append('tool_call_completed', c.toJson());
    }());
  }

  /// Starts the reply to a validated `ui_event` (`POST /messages`).
  Future<void> respondToUiEvent(
    SessionState session, {
    required String userMessageId,
    required Map<String, Object?> doc,
    required Map<String, Object?> event,
  }) async {
    final messageId = session.nextMessageId('assistant');
    final reply = ReplyState(messageId);
    session.replies[messageId] = reply;
    await _delay(_o.thinkDelay);
    if (session.ended) return;
    session.append('assistant_message_started', {
      'message_id': messageId,
      'in_reply_to': userMessageId,
    });
    await respondUiEvent(session, reply, doc, event);
  }

  /// A `ui_event` from `POST /messages` (already validated).
  Future<void> respondUiEvent(
    SessionState session,
    ReplyState reply,
    Map<String, Object?> doc,
    Map<String, Object?> event,
  ) async {
    final ar = session.languageTag == 'ar';
    final options =
        (event['option_ids'] as List?)?.whereType<String>().toList() ??
        const [];
    switch (doc['category']) {
      case 'places_maps' when options.isNotEmpty:
        final i = session.lastPlaces.indexWhere(
          (p) => p['id'] == options.first,
        );
        await _directions(session, reply, i + 1, ar: ar);
      case 'themes_appearance' when options.isNotEmpty:
        final p = palettes.where((p) => p['id'] == options.first).firstOrNull;
        if (p == null) {
          await _say(session, reply, ar ? 'لون غير معروف.' : 'Unknown colour.');
          return;
        }
        final c = await _device(session, 'app.theme.apply', {
          'palette_id': p['id'],
          'mode': 'system',
          // Resolved by the server (contract `theme.flow`).
          'colors': p['colors'],
        });
        final label = (p['label']! as Map)[ar ? 'ar' : 'en'];
        await _say(
          session,
          reply,
          _ok(c) && c!.result?['status'] == 'applied'
              ? (ar ? 'طبّقت اللون $label.' : 'Applied $label.')
              : _deviceText(c, ar),
        );
      default:
        await _say(session, reply, ar ? 'وصل اختيارك.' : 'Got your choice.');
    }
  }

  static int? _ordinal(String lower) {
    const words = {
      'first': 1,
      '1st': 1,
      'الأول': 1,
      'الاول': 1,
      'second': 2,
      '2nd': 2,
      'الثاني': 2,
      'الثانية': 2,
      'third': 3,
      '3rd': 3,
      'الثالث': 3,
      'الثالثة': 3,
    };
    for (final e in words.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return null;
  }

  static String _deviceText(ContractCall? c, bool ar) {
    if (c == null) {
      return ar ? 'هذا التطبيق لا يدعم ذلك.' : "This app doesn't support that.";
    }
    final r = c.result ?? const {};
    switch (c.status) {
      case 'succeeded':
        return switch (c.tool) {
          'device.location.get_current' =>
            ar
                ? 'أنت عند ${r['latitude']}, ${r['longitude']} (بدقة ${(r['accuracy_m'] as num?)?.round()} م).'
                : 'You are at ${r['latitude']}, ${r['longitude']} (accurate to ${(r['accuracy_m'] as num?)?.round()} m).',
          'device.network.get_status' =>
            r['online'] == true
                ? (ar ? 'متصل عبر ${r['type']}.' : 'Online via ${r['type']}.')
                : (ar ? 'غير متصل.' : 'Offline.'),
          'device.camera.capture' || 'device.photo.pick' =>
            ar
                ? 'وصلت الصورة. تحليل الصور غير متاح في البوابة المرجعية.'
                : 'Got the photo. Image analysis is not available in the reference gateway.',
          'app.theme.apply' =>
            r['status'] == 'applied'
                ? (ar ? 'تم تطبيق الألوان.' : 'Colours applied.')
                : (ar ? 'لم تتغير الألوان.' : 'Colours unchanged.'),
          'app.theme.reset' =>
            r['status'] == 'reset'
                ? (ar
                      ? 'استعدت الألوان الأصلية.'
                      : 'Original colours restored.')
                : (ar ? 'لم يتغير شيء.' : 'Nothing changed.'),
          _ => ar ? 'تم.' : 'Done.',
        };
      case 'denied':
        return ar ? 'حسناً، لن أفعل ذلك.' : "Okay, I won't.";
      case 'expired':
        return ar ? 'لم يصل رد في الوقت.' : 'No answer came in time.';
      case 'cancelled':
        return ar ? 'أُلغي.' : 'Cancelled.';
      default:
        final code = c.error?['code'];
        return switch (code) {
          'permission_denied' =>
            ar ? 'الإذن غير ممنوح.' : "Permission isn't granted.",
          'cancelled' => ar ? 'حسناً، لن أفعل ذلك.' : "Okay, I won't.",
          _ => ar ? 'لم يكتمل ذلك.' : "That didn't complete.",
        };
    }
  }

  Future<void> _say(SessionState session, ReplyState reply, String text) async {
    final words = _words(text);
    await _streamWords(session, reply, words, _o.deltaDelay);
    reply.finished = true;
    session.append('assistant_message_completed', {
      'message_id': reply.messageId,
      'finish_reason': 'stop',
      'full_text': words.join(' '),
    });
  }

  /// Marks a reply cancelled; the streaming loop notices on its next delta.
  bool requestCancel(SessionState session, String messageId) {
    final reply = session.replies[messageId];
    if (reply == null || reply.finished) return false;
    reply.cancelRequested = true;
    return true;
  }

  Future<void> _weather(
    SessionState session,
    ReplyState reply, {
    required bool ar,
  }) async {
    final callId = 'tool_${session.lastSequence + 1}';
    session.append('tool_call_requested', {
      'message_id': reply.messageId,
      'tool_call': {
        'id': callId,
        'tool_name': 'weather.current',
        'display_title': ar ? 'جلب حالة الطقس' : 'Fetching the weather',
        'requires_confirmation': false,
      },
    });
    session.append('tool_execution_progress', {
      'tool_call_id': callId,
      'status': 'running',
      'progress': 0.3,
    });
    await _delay(_o.thinkDelay);
    if (reply.cancelRequested || session.ended) {
      _finishCancelled(session, reply);
      return;
    }
    session.append('tool_result_received', {
      'tool_call_id': callId,
      'message_id': reply.messageId,
      'result': {
        'kind': 'weather',
        'weather': {
          'location_name': ar ? 'بغداد' : 'Baghdad',
          'temperature_c': 34.0,
          'condition': ar ? 'مشمس' : 'Sunny',
          'icon_key': 'clear',
          'feels_like_c': 36.0,
          'humidity_percent': 18.0,
          'wind_kph': 12.0,
          'forecast': [
            {
              'date': '2026-10-23T00:00:00Z',
              'high_c': 35.0,
              'low_c': 21.0,
              'condition': 'Sunny',
              'icon_key': 'clear',
            },
            {
              'date': '2026-10-24T00:00:00Z',
              'high_c': 33.0,
              'low_c': 20.0,
              'condition': 'Cloudy',
              'icon_key': 'cloudy',
            },
          ],
        },
      },
    });
    final words = _words(
      ar
          ? 'الطقس في بغداد مشمس، 34 درجة.'
          : 'It is sunny in Baghdad, 34 degrees.',
    );
    await _streamWords(session, reply, words, _o.deltaDelay);
    if (reply.cancelRequested || session.ended) {
      _finishCancelled(session, reply);
      return;
    }
    reply.finished = true;
    session.append('assistant_message_completed', {
      'message_id': reply.messageId,
      'finish_reason': 'stop',
      'full_text': words.join(' '),
    });
  }

  Future<void> _booking(
    SessionState session,
    ReplyState reply, {
    required bool ar,
  }) async {
    final callId = 'tool_${session.lastSequence + 1}';
    final confirmationId = 'cfm_$callId';
    session.toolCalls[callId] = PendingToolCall(
      id: callId,
      name: 'book_table',
      messageId: reply.messageId,
      confirmationId: confirmationId,
    );
    session.append('tool_call_requested', {
      'message_id': reply.messageId,
      'tool_call': {
        'id': callId,
        'tool_name': 'restaurants.book',
        'display_title': ar ? 'حجز طاولة' : 'Booking a table',
        'requires_confirmation': true,
      },
    });
    session.append('user_confirmation_requested', {
      'tool_call_id': callId,
      'confirmation': {
        'id': confirmationId,
        'title': ar ? 'تأكيد الحجز' : 'Confirm booking',
        'description': ar
            ? 'حجز طاولة لشخصين الساعة 8 مساءً؟'
            : 'Book a table for two at 8 pm?',
        'confirm_label': ar ? 'احجز' : 'Book',
        'decline_label': ar ? 'إلغاء' : 'Cancel',
        'severity': 'medium',
        'details': [ar ? 'شخصان' : 'Party of 2', '20:00'],
      },
    });
  }

  Future<void> _streamWords(
    SessionState session,
    ReplyState reply,
    List<String> words,
    Duration delay,
  ) async {
    for (var i = 0; i < words.length; i++) {
      if (reply.cancelRequested || session.ended) return;
      if (i == 2 && session.chaos.dropStreamAfterSequence == -1) {
        // Armed by the "interrupt" scenario: the 3rd delta is the last one
        // written before the SSE connection is dropped; the next long-poll
        // answers 503 once.
        session.chaos.dropStreamAfterSequence = session.lastSequence + 1;
        session.chaos.failNextPoll = true;
      }
      session.append('assistant_text_delta', {
        'message_id': reply.messageId,
        'delta_index': i,
        'text': i == 0 ? words[i] : ' ${words[i]}',
      });
      await _delay(delay);
    }
  }

  void _finishCancelled(SessionState session, ReplyState reply) {
    if (reply.finished) return;
    reply.finished = true;
    if (!session.ended) {
      session.append('message_cancelled', {'message_id': reply.messageId});
    }
  }

  List<String> _replyWords(String text, String lower, {required bool ar}) {
    if (lower.contains('interrupt')) {
      // -1 = armed, replaced by the real sequence when the 3rd delta is written.
      return _words(
        ar
            ? 'هذا الرد سيُقطع عمداً بعد الكلمة الثالثة ثم يستأنف بعد إعادة الاتصال بنجاح.'
            : 'This reply is deliberately interrupted after the third word and then resumes once the SDK reconnects successfully.',
      );
    }
    if (lower.contains('long') || lower.contains('slow')) {
      final base = ar
          ? 'هذا رد طويل من بوابة NEXA المرجعية لاختبار التمرير والإيقاف.'
          : 'This is a long scripted reply from the NEXA reference gateway used to test scrolling and stop.';
      final words = _words(base);
      return [for (var i = 0; i < 12; i++) ...words];
    }
    final quoted = text.trim();
    return _words(
      ar
          ? 'قلت: "$quoted". هذا الرد مُولَّد من بوابة NEXA المرجعية المحلية (بنية تطوير، وليس نموذجاً).'
          : 'You said: "$quoted". This reply is streamed by the local NEXA reference gateway (development infrastructure, not a model).',
    );
  }

  static List<String> _words(String s) =>
      s.split(' ').where((w) => w.isNotEmpty).toList();

  Future<void> _delay(Duration d) =>
      d == Duration.zero ? Future<void>.value() : Future<void>.delayed(d);
}
