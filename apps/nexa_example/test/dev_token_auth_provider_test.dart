import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_example/dev_token_auth_provider.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  test('no token: the SDK gets an authentication error, not a crash', () {
    expect(
      DevTokenAuthProvider().fetchSessionCredential(),
      throwsA(isA<AuthenticationException>()),
    );
  });

  test(
    'pasted token is trimmed and forwarded with its stated expiry',
    () async {
      final auth = DevTokenAuthProvider();
      var notified = 0;
      auth.addListener(() => notified++);
      final expiry = DateTime.utc(2030, 1, 1);
      auth.setToken('  nxs_test  \n', expiresAt: expiry);
      final c = await auth.fetchSessionCredential();
      expect(c.token, 'nxs_test');
      expect(c.expiresAt, expiry);
      expect(c.scopes, contains('voice:session'));
      expect(notified, 1);
      expect(auth.toString(), isNot(contains('nxs_test')));
    },
  );

  test('expired and cleared states', () {
    final auth = DevTokenAuthProvider(
      token: 'nxs_old',
      expiresAt: DateTime.utc(2020),
    );
    expect(auth.isExpired, isTrue);
    auth.clear();
    expect(auth.hasToken, isFalse);
  });
}
