import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

void main() {
  group('NexaConfig.validate', () {
    NexaConfig base({
      String appId = 'app_1',
      String uri = 'https://gw.example.com',
      NexaEnvironment env = NexaEnvironment.production,
      String lang = 'en',
      Map<String, String> meta = const {},
    }) => NexaConfig(
      applicationId: appId,
      gatewayBaseUri: Uri.parse(uri),
      environment: env,
      languageTag: lang,
      clientMetadata: meta,
    );

    test(
      'accepts a sane config',
      () => expect(base().validate, returnsNormally),
    );
    test(
      'rejects empty app id',
      () => expect(
        base(appId: ' ').validate,
        throwsA(isA<ConfigurationException>()),
      ),
    );
    test(
      'rejects http in production',
      () => expect(
        base(uri: 'http://gw').validate,
        throwsA(isA<ConfigurationException>()),
      ),
    );
    test(
      'allows http in development',
      () => expect(
        base(
          uri: 'http://localhost:8080',
          env: NexaEnvironment.development,
        ).validate,
        returnsNormally,
      ),
    );
    test(
      'rejects unsupported language',
      () => expect(
        base(lang: 'fr').validate,
        throwsA(isA<ConfigurationException>()),
      ),
    );
    test(
      'rejects credential-looking metadata',
      () => expect(
        base(meta: {'api_key': 'x'}).validate,
        throwsA(isA<ConfigurationException>()),
      ),
    );
  });
}
