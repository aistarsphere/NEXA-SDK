import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/network/error_mapper.dart';

/// REST surface of contract `labeeb.sdk/1` beyond the chat event stream:
/// conversations and history, attachments, the tool catalogue and the
/// tool-call lifecycle, preferences and data deletion.
///
/// Uses the SDK's [Dio] (bearer `nxs_` token, `X-Nexa-App-Id`,
/// `X-Nexa-Sdk-Version`, installation id). Every failure is a mapped
/// `NexaException`; the gateway's `error.code` is kept, never guessed.
final class LabeebSdkClient {
  LabeebSdkClient(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on Object catch (e) {
      throw mapError(e);
    }
  }

  Map<String, Object?> _map(Object? v) =>
      v is Map ? v.cast<String, Object?>() : const {};

  // ------------------------------------------------------------ contract

  /// `GET /v1/sdk/contract` (unauthenticated document).
  Future<Map<String, Object?>> contract() => _call(() async {
    final r = await _dio.get<Object?>('/v1/sdk/contract');
    return _map(r.data);
  });

  // ---------------------------------------------------------------- tools

  /// `GET /v1/sdk/tools` (scope `tools:use`).
  Future<LabeebToolCatalogue> tools() => _call(() async {
    final r = await _dio.get<Object?>('/v1/sdk/tools');
    final j = _map(r.data);
    return LabeebToolCatalogue(
      enabled: j['enabled'] == true,
      tools: [
        for (final t in (j['tools'] as List?) ?? const [])
          if (t is Map && t['name'] is String)
            LabeebToolEntry.fromJson(t.cast<String, Object?>()),
      ],
    );
  });

  String _tc(String sessionId, String toolCallId) =>
      '/v1/sdk/sessions/$sessionId/tool-calls/$toolCallId';

  NexaToolCall _toolCall(Object? data, String id) =>
      NexaToolCall.fromJson({'tool_call_id': id, ..._map(data)}) ??
      (throw const ContractViolationException('tool call missing'));

  /// `GET .../tool-calls/{id}` (also returns `result.ui`).
  Future<NexaToolCall> toolCall(String sessionId, String toolCallId) =>
      _call(() async {
        final r = await _dio.get<Object?>(_tc(sessionId, toolCallId));
        return _toolCall(r.data, toolCallId);
      });

  /// `POST .../approval {granted}`.
  Future<NexaToolCall> approve(
    String sessionId,
    String toolCallId, {
    required bool granted,
  }) => _call(() async {
    final r = await _dio.post<Object?>(
      '${_tc(sessionId, toolCallId)}/approval',
      data: {'granted': granted},
    );
    return _toolCall(r.data, toolCallId);
  });

  /// `POST .../result` with `{result}` or `{error}`; accepted once.
  Future<NexaToolCall> answer(
    String sessionId,
    String toolCallId,
    NexaToolCallAnswer answer,
  ) => _call(() async {
    final r = await _dio.post<Object?>(
      '${_tc(sessionId, toolCallId)}/result',
      data: answer.toJson(),
    );
    return _toolCall(r.data, toolCallId);
  });

  /// `POST .../cancel` (also cancels the GPU job of a long call).
  Future<void> cancelToolCall(String sessionId, String toolCallId) =>
      _call(() => _dio.post<Object?>('${_tc(sessionId, toolCallId)}/cancel'));

  // -------------------------------------------------------- conversations

  /// `POST /v1/sdk/conversations` (idempotent per [clientRef]).
  Future<LabeebConversation> createConversation({
    String? title,
    String kind = 'chat',
    String? clientRef,
  }) => _call(() async {
    final r = await _dio.post<Object?>(
      '/v1/sdk/conversations',
      data: {'title': ?title, 'kind': kind, 'client_ref': ?clientRef},
    );
    return LabeebConversation.fromJson(_map(r.data));
  });

  /// `GET /v1/sdk/conversations` (newest activity first).
  Future<LabeebConversationPage> conversations({
    String? cursor,
    int limit = 20,
    String? kind,
    String? installation,
  }) => _call(() async {
    final r = await _dio.get<Object?>(
      '/v1/sdk/conversations',
      queryParameters: {
        'limit': limit,
        'cursor': ?cursor,
        'kind': ?kind,
        'installation': ?installation,
      },
    );
    final j = _map(r.data);
    return LabeebConversationPage([
      for (final c in (j['items'] as List?) ?? const [])
        if (c is Map) LabeebConversation.fromJson(c.cast<String, Object?>()),
    ], nextCursor: j['next_cursor'] as String?);
  });

  Future<LabeebConversation> conversation(String id) => _call(() async {
    final r = await _dio.get<Object?>('/v1/sdk/conversations/$id');
    return LabeebConversation.fromJson(_map(r.data));
  });

  Future<LabeebConversation> renameConversation(String id, String title) =>
      _call(() async {
        final r = await _dio.patch<Object?>(
          '/v1/sdk/conversations/$id',
          data: {'title': title},
        );
        return LabeebConversation.fromJson(_map(r.data));
      });

  /// Returns the server's `deleted` counts.
  Future<Map<String, int>> deleteConversation(String id) => _call(() async {
    final r = await _dio.delete<Object?>('/v1/sdk/conversations/$id');
    return _counts(r.data);
  });

  /// `DELETE /v1/sdk/conversations[?kind=chat|voice]`.
  Future<Map<String, int>> clearConversations({String? kind}) =>
      _call(() async {
        final r = await _dio.delete<Object?>(
          '/v1/sdk/conversations',
          queryParameters: {'kind': ?kind},
        );
        return _counts(r.data);
      });

  Map<String, int> _counts(Object? data) {
    final d = _map(_map(data)['deleted']);
    return {
      for (final MapEntry(:key, :value) in d.entries)
        if (value is int) key: value,
    };
  }

  /// Chronological page; [beforeSeq] pages to older messages.
  Future<LabeebMessagePage> messages(
    String conversationId, {
    int limit = 50,
    int? beforeSeq,
  }) => _call(() async {
    final r = await _dio.get<Object?>(
      '/v1/sdk/conversations/$conversationId/messages',
      queryParameters: {'limit': limit, 'before_seq': ?beforeSeq},
    );
    final j = _map(r.data);
    return LabeebMessagePage([
      for (final m in (j['items'] as List?) ?? const [])
        if (m is Map) LabeebMessage.fromJson(m.cast<String, Object?>()),
    ], nextBefore: j['next_before'] as int?);
  });

  /// Spoken turns of a call into the shared conversation (idempotent per
  /// `client_turn_id`). Returns `server_recorded`.
  Future<bool> reportVoiceTurns(
    String conversationId, {
    required String voiceSessionId,
    required List<LabeebVoiceTurn> turns,
  }) => _call(() async {
    final r = await _dio.post<Object?>(
      '/v1/sdk/conversations/$conversationId/voice-turns',
      data: {
        'voice_session_id': voiceSessionId,
        'turns': [for (final t in turns) t.toJson()],
      },
    );
    return _map(r.data)['server_recorded'] == true;
  });

  // --------------------------------------------------------------- assets

  /// Raw upload (`image/png|jpeg|webp`, `application/pdf`,
  /// `text/plain|markdown|csv`, `application/json`; 10 MB).
  Future<NexaAssetRef> uploadAsset(
    String conversationId,
    Uint8List bytes, {
    required String mime,
    String? filename,
  }) => _call(() async {
    final r = await _dio.post<Object?>(
      '/v1/sdk/conversations/$conversationId/assets',
      data: Stream.fromIterable([bytes]),
      options: Options(
        contentType: mime,
        headers: {
          Headers.contentLengthHeader: bytes.length,
          'X-Nexa-Filename': ?filename,
        },
      ),
    );
    return NexaAssetRef.fromJson(_map(r.data)) ??
        (throw const ContractViolationException('asset missing'));
  });

  Future<NexaAssetRef> asset(String id) => _call(() async {
    final r = await _dio.get<Object?>('/v1/sdk/assets/$id');
    return NexaAssetRef.fromJson(_map(r.data)) ??
        (throw const ContractViolationException('asset missing'));
  });

  /// Asset bytes (never cached by the SDK beyond memory).
  Future<Uint8List> assetContent(String id) => _call(() async {
    final r = await _dio.get<List<int>>(
      '/v1/sdk/assets/$id/content',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(r.data ?? const []);
  });

  Future<void> deleteAsset(String id) =>
      _call(() => _dio.delete<Object?>('/v1/sdk/assets/$id'));

  // ---------------------------------------------------------- preferences

  Future<Map<String, Object?>> preferences() => _call(() async {
    final r = await _dio.get<Object?>('/v1/sdk/me/preferences');
    return _map(_map(r.data)['preferences']);
  });

  /// Replaces all preferences (flat keys, ≤30, strings ≤200).
  Future<Map<String, Object?>> putPreferences(Map<String, Object?> p) =>
      _call(() async {
        final r = await _dio.put<Object?>(
          '/v1/sdk/me/preferences',
          data: {'preferences': p},
        );
        return _map(_map(r.data)['preferences']);
      });

  Future<void> deletePreferences() =>
      _call(() => _dio.delete<Object?>('/v1/sdk/me/preferences'));

  /// `GET /assistant`: the identity and appearance the company set for
  /// this application (data for the host to render in its own design).
  Future<LabeebAssistantProfile> assistantProfile() => _call(() async {
    final r = await _dio.get<Object?>('/v1/sdk/assistant');
    return LabeebAssistantProfile.fromJson(_map(r.data));
  });

  /// Everything this subject owns in this app.
  Future<Map<String, int>> deleteAssistantData() => _call(() async {
    final r = await _dio.delete<Object?>('/v1/sdk/me/assistant-data');
    return _counts(r.data);
  });
}

/// `GET /tools`.
@immutable
final class LabeebToolCatalogue {
  const LabeebToolCatalogue({required this.enabled, required this.tools});
  final bool enabled;
  final List<LabeebToolEntry> tools;

  LabeebToolEntry? operator [](String name) =>
      tools.where((t) => t.name == name).firstOrNull;
}

@immutable
final class LabeebToolEntry {
  const LabeebToolEntry({
    required this.name,
    required this.available,
    this.unavailableReason,
    this.side,
    this.group,
    this.raw = const {},
  });

  factory LabeebToolEntry.fromJson(Map<String, Object?> j) => LabeebToolEntry(
    name: j['name']! as String,
    available: j['available'] == true,
    unavailableReason: j['unavailable_reason'] as String?,
    side: j['side'] as String?,
    group: j['group'] as String?,
    raw: j,
  );

  final String name;
  final bool available;

  /// `availability.tool_unavailable_reasons` (open).
  final String? unavailableReason;
  final String? side;
  final String? group;
  final Map<String, Object?> raw;
}

/// A server-owned conversation.
@immutable
final class LabeebConversation {
  const LabeebConversation({
    required this.id,
    this.title,
    this.titleSource,
    this.kind = 'chat',
    this.messageCount = 0,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.activeSessionId,
    this.latestSessionId,
  });

  factory LabeebConversation.fromJson(Map<String, Object?> j) {
    DateTime? at(String k) =>
        j[k] is String ? DateTime.tryParse(j[k]! as String) : null;
    final sessions = j['sessions'] is Map
        ? (j['sessions']! as Map).cast<String, Object?>()
        : const <String, Object?>{};
    return LabeebConversation(
      id: j['id']! as String,
      title: j['title'] as String?,
      titleSource: j['title_source'] as String?,
      kind: j['kind'] as String? ?? 'chat',
      messageCount: j['message_count'] is int ? j['message_count']! as int : 0,
      createdAt: at('created_at'),
      updatedAt: at('updated_at'),
      lastMessageAt: at('last_message_at'),
      activeSessionId: sessions['active'] as String?,
      latestSessionId: sessions['latest'] as String?,
    );
  }

  final String id;
  final String? title;

  /// `auto|user`.
  final String? titleSource;
  final String kind;
  final int messageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;

  /// For resume (`GET /conversations/{id}` only).
  final String? activeSessionId;
  final String? latestSessionId;
}

@immutable
final class LabeebConversationPage {
  const LabeebConversationPage(this.items, {this.nextCursor});
  final List<LabeebConversation> items;
  final String? nextCursor;
}

/// A stored message (`role`, `text`, typed `parts`, `seq`).
@immutable
final class LabeebMessage {
  const LabeebMessage({
    required this.id,
    required this.role,
    required this.text,
    this.seq,
    this.channel,
    this.status,
    this.parts = const [],
    this.createdAt,
    this.sessionId,
  });

  factory LabeebMessage.fromJson(Map<String, Object?> j) => LabeebMessage(
    id: j['id'] as String? ?? '',
    role: j['role'] as String? ?? 'assistant',
    text: j['text'] as String? ?? '',
    seq: j['seq'] as int?,
    channel: j['channel'] as String?,
    status: j['status'] as String?,
    parts: [
      for (final p in (j['parts'] as List?) ?? const [])
        if (p is Map) p.cast<String, Object?>(),
    ],
    createdAt: j['created_at'] is String
        ? DateTime.tryParse(j['created_at']! as String)
        : null,
    sessionId: j['session_id'] as String?,
  );

  final String id;

  /// `user|assistant` (others shown as assistant-side system text).
  final String role;
  final String text;
  final int? seq;

  /// `chat|voice`.
  final String? channel;
  final String? status;

  /// `contract.message_parts`: text, image, file, tool_request,
  /// tool_result, tool_error, ui_event, deleted_asset.
  final List<Map<String, Object?>> parts;
  final DateTime? createdAt;

  /// The chat session the message was exchanged in (`ses_*`): where its
  /// tool calls are read (`GET /sessions/{id}/tool-calls/{tc}`).
  final String? sessionId;

  bool get fromUser => role == 'user';
}

@immutable
final class LabeebMessagePage {
  const LabeebMessagePage(this.items, {this.nextBefore});
  final List<LabeebMessage> items;

  /// Pass as `before_seq` for older messages; null at the start.
  final int? nextBefore;
}

@immutable
final class LabeebVoiceTurn {
  const LabeebVoiceTurn({
    required this.role,
    required this.text,
    required this.clientTurnId,
  });
  final String role;
  final String text;
  final String clientTurnId;

  Map<String, Object?> toJson() => {
    'role': role,
    'text': text,
    'client_turn_id': clientTurnId,
  };
}

/// `GET /assistant`. Unset values are null; the host keeps its own
/// defaults for them. Only an https logo and a `#RRGGBB` colour are kept.
@immutable
final class LabeebAssistantProfile {
  const LabeebAssistantProfile({
    required this.applicationId,
    this.applicationName,
    this.environment,
    this.assistantName,
    this.accentColor,
    this.logoUrl,
    this.welcomeMessage,
  });

  factory LabeebAssistantProfile.fromJson(Map<String, Object?> j) {
    final a = j['assistant'] is Map
        ? (j['assistant']! as Map).cast<String, Object?>()
        : const <String, Object?>{};
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    final color = text(a['accent_color']);
    final logo = text(a['logo_url']);
    return LabeebAssistantProfile(
      applicationId: j['application_id'] as String? ?? '',
      applicationName: text(j['application_name']),
      environment: text(j['environment']),
      assistantName: text(a['assistant_name']),
      accentColor: color != null && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)
          ? int.parse('FF${color.substring(1)}', radix: 16)
          : null,
      logoUrl: logo != null && isHttpsUrl(logo) ? Uri.parse(logo) : null,
      welcomeMessage: text(a['welcome_message']),
    );
  }

  final String applicationId;
  final String? applicationName;

  /// `dev|staging|prod`.
  final String? environment;
  final String? assistantName;

  /// ARGB, e.g. for `Color(accentColor!)`.
  final int? accentColor;
  final Uri? logoUrl;
  final String? welcomeMessage;
}
