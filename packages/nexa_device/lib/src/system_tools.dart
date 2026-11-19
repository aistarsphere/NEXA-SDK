import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart' as conn;
import 'package:network_info_plus/network_info_plus.dart' as ni;
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/src/device_ui.dart';
import 'package:nexa_device/src/directions_tool.dart';
import 'package:nexa_device/src/location_tool.dart';
import 'package:nexa_device/src/media_store.dart';
import 'package:share_plus/share_plus.dart';

const _both = {ClientToolPlatform.android, ClientToolPlatform.ios};

ClientToolResult _fail(
  ClientToolRequest r,
  ClientToolErrorCode code, {
  String? message,
  bool retryable = false,
  bool settings = false,
}) => ClientToolResult.failure(
  r,
  ClientToolError(
    code,
    message ?? code.name,
    retryable: retryable,
    canOpenSettings: settings,
  ),
);

// =================================================================== network

/// Connectivity facts the OS gives without special permission, plus the
/// Wi-Fi SSID where the OS allows it.
abstract interface class NexaNetworkPlatform {
  /// `wifi`, `mobile`, `ethernet`, `vpn`, `bluetooth`, `other` (empty: none).
  Future<List<String>> connectionTypes();

  /// The SSID, or null when the OS does not reveal it.
  Future<String?> wifiName();
}

final class PluginNetworkPlatform implements NexaNetworkPlatform {
  const PluginNetworkPlatform();

  @override
  Future<List<String>> connectionTypes() async => [
    for (final r in await conn.Connectivity().checkConnectivity())
      if (r != conn.ConnectivityResult.none) r.name,
  ];

  @override
  Future<String?> wifiName() async {
    final raw = await ni.NetworkInfo().getWifiName();
    if (raw == null) return null;
    final name = raw.replaceAll('"', '').trim();
    // Android returns this placeholder without location permission.
    return name.isEmpty || name == '<unknown ssid>' ? null : name;
  }
}

/// `device.network.get_status` v1: connection types. Interfaces only, not a
/// reachability test. No approval (nothing personal).
final class NetworkStatusTool implements ClientToolExecutor {
  NetworkStatusTool({this.network = const PluginNetworkPlatform()});

  static const id = 'device.network.get_status';
  final NexaNetworkPlatform network;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Network status',
    requiresApproval: false,
    sensitivity: ClientToolSensitivity.low,
    timeout: Duration(seconds: 10),
    platforms: _both,
    inputSchema: {'type': 'object', 'additionalProperties': false},
    outputSchema: {
      'type': 'object',
      'required': ['connected', 'types'],
      'properties': {
        'connected': {'type': 'boolean'},
        'types': {'type': 'array'},
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final types = await network.connectionTypes();
    return ClientToolResult.success(request, {
      'connected': types.isNotEmpty,
      'types': types,
    });
  }
}

/// `device.wifi.get_current_info` v1: whether the device is on Wi-Fi and,
/// where the OS permits, the SSID. Never passwords, never other networks.
/// iOS needs location permission **and** the app's Access Wi-Fi Information
/// entitlement; Android needs location permission.
final class WifiInfoTool implements ClientToolExecutor {
  WifiInfoTool({
    this.network = const PluginNetworkPlatform(),
    this.location = const GeolocatorLocationPlatform(),
  });

  static const id = 'device.wifi.get_current_info';
  final NexaNetworkPlatform network;
  final LocationPlatform location;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Wi-Fi network',
    requiredPermissions: {ClientToolPermission.location},
    timeout: Duration(seconds: 60),
    platforms: _both,
    inputSchema: {'type': 'object', 'additionalProperties': false},
    outputSchema: {
      'type': 'object',
      'required': ['on_wifi', 'ssid_available'],
      'properties': {
        'on_wifi': {'type': 'boolean'},
        'ssid': {'type': 'string'},
        'ssid_available': {'type': 'boolean'},
        'ssid_unavailable_reason': {
          'type': 'string',
          'enum': ['not_on_wifi', 'permission_denied', 'not_permitted_by_os'],
        },
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final onWifi = (await network.connectionTypes()).contains('wifi');
    if (!onWifi) {
      return ClientToolResult.success(request, {
        'on_wifi': false,
        'ssid_available': false,
        'ssid_unavailable_reason': 'not_on_wifi',
      });
    }
    var permission = await location.permission();
    if (permission == LocationPermissionState.notDetermined ||
        permission == LocationPermissionState.denied) {
      onPhase(ClientToolRunPhase.awaitingPermission);
      permission = await location.requestPermission();
      onPhase(ClientToolRunPhase.running);
    }
    if (permission != LocationPermissionState.granted) {
      return ClientToolResult.success(request, {
        'on_wifi': true,
        'ssid_available': false,
        'ssid_unavailable_reason': 'permission_denied',
      });
    }
    final ssid = await network.wifiName();
    return ClientToolResult.success(request, {
      'on_wifi': true,
      'ssid_available': ssid != null,
      'ssid': ?ssid,
      if (ssid == null) 'ssid_unavailable_reason': 'not_permitted_by_os',
    });
  }
}

// =================================================================== browser

/// Validates a URL for `device.browser.open_url`: https only, a host, no
/// embedded credentials, ≤ 2048 chars, and (when set) a host allowlist.
Uri? validateBrowserUrl(String raw, {Set<String>? allowedHosts}) {
  if (raw.length > 2048) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  if (uri.userInfo.isNotEmpty) return null;
  final hosts = allowedHosts;
  if (hosts != null &&
      !hosts.any((h) => uri.host == h || uri.host.endsWith('.$h'))) {
    return null;
  }
  return uri;
}

/// `device.browser.open_url` v1: opens one validated https URL outside the
/// app after the user approves.
final class BrowserOpenTool implements ClientToolExecutor {
  BrowserOpenTool({this.opener = const PluginUrlOpener(), this.allowedHosts});

  static const id = 'device.browser.open_url';
  final UrlOpener opener;

  /// Host allowlist (null: any https host).
  final Set<String>? allowedHosts;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Open website',
    sensitivity: ClientToolSensitivity.external,
    timeout: Duration(seconds: 30),
    platforms: _both,
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['url'],
      'properties': {
        'url': {'type': 'string'},
        'title': {'type': 'string'},
      },
    },
    outputSchema: {
      'type': 'object',
      'required': ['url', 'opened'],
      'properties': {
        'url': {'type': 'string'},
        'opened': {'type': 'boolean'},
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final url = validateBrowserUrl(
      '${request.arguments['url']}',
      allowedHosts: allowedHosts,
    );
    if (url == null) {
      return _fail(
        request,
        ClientToolErrorCode.invalidArguments,
        message: 'https URL required (no credentials, allowed host)',
      );
    }
    if (!await opener.openInBrowser(url)) {
      return _fail(request, ClientToolErrorCode.unsupported, retryable: true);
    }
    return ClientToolResult.success(request, {
      'url': url.toString(),
      'opened': true,
    });
  }
}

// ====================================================================== apps

/// An app the host allows the assistant to open, with verified ways to do
/// it. Hosts list these; the SDK never enumerates installed apps.
final class NexaAppTarget {
  const NexaAppTarget({
    required this.id,
    required this.name,
    this.iosUri,
    this.androidUri,
    this.fallbackUri,
  });

  /// Stable id the backend uses (e.g. `google_maps`).
  final String id;
  final String name;

  /// Custom scheme or universal link per platform (e.g. `comgooglemaps://`).
  final Uri? iosUri;
  final Uri? androidUri;

  /// Web fallback when the app is not installed.
  final Uri? fallbackUri;

  Uri? uriFor(ClientToolPlatform p) =>
      p == ClientToolPlatform.ios ? iosUri : androidUri;
}

ClientToolPlatform get currentToolPlatform =>
    Platform.isIOS ? ClientToolPlatform.ios : ClientToolPlatform.android;

/// `device.app.open` v1: opens one allowlisted app (or its web fallback).
final class AppOpenTool implements ClientToolExecutor {
  AppOpenTool({
    required this.apps,
    this.opener = const PluginUrlOpener(),
    ClientToolPlatform? platform,
  }) : _platform = platform;

  static const id = 'device.app.open';
  final List<NexaAppTarget> apps;
  final UrlOpener opener;
  final ClientToolPlatform? _platform;

  @override
  late final ClientToolDescriptor descriptor = ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Open app',
    sensitivity: ClientToolSensitivity.external,
    timeout: const Duration(seconds: 30),
    platforms: _both,
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'required': ['app_id'],
      'properties': {
        'app_id': {
          'type': 'string',
          'enum': [for (final a in apps) a.id],
        },
      },
    },
    outputSchema: const {
      'type': 'object',
      'required': ['app_id', 'opened_in'],
      'properties': {
        'app_id': {'type': 'string'},
        'opened_in': {
          'type': 'string',
          'enum': ['app', 'browser'],
        },
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async => apps.isEmpty
      ? ClientToolAvailability.disabledByHost
      : ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final appId = request.arguments['app_id'];
    final app = apps.where((a) => a.id == appId).firstOrNull;
    if (app == null) {
      return _fail(request, ClientToolErrorCode.invalidArguments);
    }
    final uri = app.uriFor(_platform ?? currentToolPlatform);
    if (uri != null) {
      final web = uri.scheme == 'https' || uri.scheme == 'http';
      final opened = web
          ? await opener.openInApp(uri)
          : await opener.openInBrowser(uri); // custom scheme → its app
      if (opened) {
        return ClientToolResult.success(request, {
          'app_id': app.id,
          'opened_in': 'app',
        });
      }
    }
    final fallback = app.fallbackUri;
    if (fallback != null && await opener.openInBrowser(fallback)) {
      return ClientToolResult.success(request, {
        'app_id': app.id,
        'opened_in': 'browser',
      });
    }
    return _fail(request, ClientToolErrorCode.unsupported, retryable: true);
  }
}

/// `device.apps.query_supported` v1: the host's allowlist and whether each
/// app looks installed. Running/background apps cannot be listed by
/// third-party apps on iOS or modern Android; this is reported, not worked
/// around.
final class AppsQueryTool implements ClientToolExecutor {
  AppsQueryTool({
    required this.apps,
    this.opener = const PluginUrlOpener(),
    ClientToolPlatform? platform,
  }) : _platform = platform;

  static const id = 'device.apps.query_supported';
  final List<NexaAppTarget> apps;
  final UrlOpener opener;
  final ClientToolPlatform? _platform;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Supported apps',
    requiresApproval: false,
    sensitivity: ClientToolSensitivity.low,
    timeout: Duration(seconds: 10),
    platforms: _both,
    inputSchema: {'type': 'object', 'additionalProperties': false},
    outputSchema: {
      'type': 'object',
      'required': ['apps', 'background_apps'],
      'properties': {
        'apps': {'type': 'array'},
        'background_apps': {
          'type': 'string',
          'enum': ['not_available_on_this_os'],
        },
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final list = <Map<String, Object?>>[];
    for (final a in apps) {
      final uri = a.uriFor(_platform ?? currentToolPlatform);
      final String installed;
      if (uri == null) {
        installed = 'unsupported';
      } else if (uri.scheme == 'https' || uri.scheme == 'http') {
        installed = 'unknown'; // universal links cannot be probed
      } else {
        installed = await opener.canOpen(uri) ? 'yes' : 'no';
      }
      list.add({
        'app_id': a.id,
        'name': a.name,
        'installed': installed,
        'web_fallback': a.fallbackUri != null,
      });
    }
    return ClientToolResult.success(request, {
      'apps': list,
      'background_apps': 'not_available_on_this_os',
    });
  }
}

// ===================================================================== share

/// The system share sheet. [PluginShareSheet] in apps; a fake in tests.
abstract interface class NexaShareSheet {
  /// Returns `shared`, `dismissed` or `unavailable`.
  Future<String> share({String? text, Uri? uri, List<String> filePaths});
}

final class PluginShareSheet implements NexaShareSheet {
  const PluginShareSheet();

  @override
  Future<String> share({
    String? text,
    Uri? uri,
    List<String> filePaths = const [],
  }) async {
    final r = await SharePlus.instance.share(
      ShareParams(
        text: text,
        uri: filePaths.isEmpty ? uri : null,
        files: [for (final p in filePaths) XFile(p)],
      ),
    );
    return switch (r.status) {
      ShareResultStatus.success => 'shared',
      ShareResultStatus.dismissed => 'dismissed',
      ShareResultStatus.unavailable => 'unavailable',
    };
  }
}

/// `device.share.open` v1: opens the share sheet with text, a link or an
/// attachment of this conversation. The user picks the target.
final class ShareTool implements ClientToolExecutor {
  ShareTool({
    required this.resolveAttachment,
    this.sheet = const PluginShareSheet(),
  });

  static const id = 'device.share.open';

  /// Local file of a conversation attachment (null: unknown / remote only).
  final String? Function(String attachmentId) resolveAttachment;
  final NexaShareSheet sheet;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Share',
    sensitivity: ClientToolSensitivity.external,
    timeout: Duration(minutes: 5),
    platforms: _both,
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'text': {'type': 'string'},
        'url': {'type': 'string'},
        'attachment_id': {'type': 'string'},
      },
    },
    outputSchema: {
      'type': 'object',
      'required': ['status'],
      'properties': {
        'status': {
          'type': 'string',
          'enum': ['shared', 'dismissed', 'unavailable'],
        },
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final a = request.arguments;
    final text = a['text'] as String?;
    final rawUrl = a['url'] as String?;
    final url = rawUrl == null ? null : validateBrowserUrl(rawUrl);
    final attachmentId = a['attachment_id'] as String?;
    final path = attachmentId == null ? null : resolveAttachment(attachmentId);
    if (attachmentId != null && path == null) {
      return _fail(
        request,
        ClientToolErrorCode.invalidArguments,
        message: 'attachment not available on this device',
      );
    }
    if (rawUrl != null && url == null) {
      return _fail(request, ClientToolErrorCode.invalidArguments);
    }
    if (text == null && url == null && path == null) {
      return _fail(request, ClientToolErrorCode.invalidArguments);
    }
    final status = await sheet.share(text: text, uri: url, filePaths: [?path]);
    if (status == 'dismissed') {
      return _fail(request, ClientToolErrorCode.cancelled);
    }
    if (status == 'unavailable') {
      return _fail(request, ClientToolErrorCode.unsupported);
    }
    return ClientToolResult.success(request, {'status': status});
  }
}

// ===================================================================== files

/// `device.files.pick` v1: the user picks one file (type/size checked,
/// copied into the app's store, attached to the conversation).
final class FilesPickTool implements ClientToolExecutor {
  FilesPickTool({
    required this.media,
    this.picker = const PluginFilePicker(),
    this.onAttachment,
  });

  static const id = 'device.files.pick';
  final NexaMediaStore media;
  final NexaFilePicker picker;
  void Function(NexaAttachment attachment, ClientToolRequest request)?
  onAttachment;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Pick a file',
    requiredPermissions: {ClientToolPermission.files},
    timeout: Duration(minutes: 5),
    platforms: _both,
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'reason': {'type': 'string'},
      },
    },
    outputSchema: {
      'type': 'object',
      'required': ['attachment'],
      'properties': {
        'attachment': {'type': 'object'},
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final picked = await picker.pickFile();
    if (picked == null) return _fail(request, ClientToolErrorCode.cancelled);
    switch (NexaMediaStore.checkFile(picked.name, picked.size)) {
      case 'too_large':
        return _fail(request, ClientToolErrorCode.fileTooLarge);
      case 'unsupported_type':
        return _fail(request, ClientToolErrorCode.fileTypeUnsupported);
    }
    final a = await media.importFile(picked.path, picked.name);
    onAttachment?.call(a, request);
    return ClientToolResult.success(request, {'attachment': a.toJson()});
  }
}

// ================================================================== settings

/// `device.settings.open` v1: opens this app's settings page (`app`) or the
/// location settings (`location`; on iOS this is the app's page — iOS has
/// no public deep link to system location settings).
final class SettingsOpenTool implements ClientToolExecutor {
  SettingsOpenTool({this.location = const GeolocatorLocationPlatform()});

  static const id = 'device.settings.open';
  final LocationPlatform location;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Open settings',
    sensitivity: ClientToolSensitivity.external,
    timeout: Duration(seconds: 30),
    platforms: _both,
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'target': {
          'type': 'string',
          'enum': ['app', 'location'],
        },
      },
    },
    outputSchema: {
      'type': 'object',
      'required': ['opened', 'target'],
      'properties': {
        'opened': {'type': 'boolean'},
        'target': {'type': 'string'},
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final target = request.arguments['target'] as String? ?? 'app';
    final opened = target == 'location' && !Platform.isIOS
        ? await location.openLocationSettings()
        : await location.openAppSettings();
    if (!opened) {
      return _fail(request, ClientToolErrorCode.unsupported, retryable: true);
    }
    return ClientToolResult.success(request, {
      'opened': true,
      'target': target,
    });
  }
}
