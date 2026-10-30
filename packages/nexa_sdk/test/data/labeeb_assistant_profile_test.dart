import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  test('assistant profile: set values, unsafe ones dropped', () {
    final p = LabeebAssistantProfile.fromJson({
      'application_id': 'app_1',
      'application_name': 'S1',
      'environment': 'prod',
      'assistant': {
        'assistant_name': 'Labeeb',
        'accent_color': '#1A2B3C',
        'logo_url': 'https://cdn.example/logo.png',
        'welcome_message': 'Hello',
      },
    });
    expect(p.assistantName, 'Labeeb');
    expect(p.accentColor, 0xFF1A2B3C);
    expect(p.logoUrl, Uri.parse('https://cdn.example/logo.png'));
    expect(p.welcomeMessage, 'Hello');

    final unsafe = LabeebAssistantProfile.fromJson({
      'application_id': 'app_1',
      'assistant': {
        'accent_color': 'red',
        'logo_url': 'http://insecure.example/logo.png',
        'assistant_name': '  ',
      },
    });
    expect(unsafe.accentColor, isNull);
    expect(unsafe.logoUrl, isNull);
    expect(unsafe.assistantName, isNull);
  });

  test('unset assistant block (production today) is all null', () {
    final p = LabeebAssistantProfile.fromJson({
      'application_id': 'app_1',
      'application_name': 'S1',
      'environment': 'dev',
      'assistant': {
        'assistant_name': null,
        'accent_color': null,
        'logo_url': null,
        'welcome_message': null,
      },
    });
    expect(p.applicationName, 'S1');
    expect(p.assistantName, isNull);
    expect(p.welcomeMessage, isNull);
  });
}
