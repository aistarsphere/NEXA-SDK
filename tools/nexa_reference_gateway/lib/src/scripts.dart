import 'dart:async';

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

    if (lower.contains('weather')) {
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
