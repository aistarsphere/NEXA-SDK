import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Where the installation id is kept (host-provided, app-private).
abstract interface class NexaInstallationIdStore {
  Future<String?> read();
  Future<void> write(String id);
}

/// A file in the host's private app directory: survives restarts, is removed
/// when the app is uninstalled (or by "Clear local cache" via [reset]).
final class FileInstallationIdStore implements NexaInstallationIdStore {
  FileInstallationIdStore(this.file);
  final File file;

  @override
  Future<String?> read() async {
    if (!file.existsSync()) return null;
    final v = (await file.readAsString()).trim();
    return v.isEmpty ? null : v;
  }

  @override
  Future<void> write(String id) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(id, flush: true);
  }
}

final class InMemoryInstallationIdStore implements NexaInstallationIdStore {
  String? _id;
  @override
  Future<String?> read() async => _id;
  @override
  Future<void> write(String id) async => _id = id;
}

/// Anonymous, app-scoped installation identity.
///
/// * 128 random bits from a CSPRNG (`ins_` + base64url), generated once.
/// * Not a hardware id or fingerprint, and **not** authentication: server
///   access always uses the SDK session token from the host's auth provider.
/// * Sent as `X-Nexa-Installation-Id` for correlation (diagnostics, rate
///   limits) only.
/// * [linkedAccount] is the future account-linking point: the host sets it
///   after its own sign-in; the SDK implements no login.
final class NexaInstallation {
  NexaInstallation._(this.id);

  /// Loads the id from [store], creating and saving a new one when absent
  /// or malformed.
  static Future<NexaInstallation> load(NexaInstallationIdStore store) async {
    final existing = await store.read();
    if (existing != null && isValid(existing)) {
      return NexaInstallation._(existing);
    }
    final id = generate();
    await store.write(id);
    return NexaInstallation._(id);
  }

  /// A fresh id (exposed for tests).
  @visibleForTesting
  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return 'ins_${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  static bool isValid(String id) =>
      RegExp(r'^ins_[A-Za-z0-9_-]{22}$').hasMatch(id);

  final String id;

  /// Host account this installation is linked to (future integration).
  final ValueNotifier<String?> linkedAccount = ValueNotifier(null);
}
