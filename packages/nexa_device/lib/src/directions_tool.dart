import 'package:nexa_core/nexa_core.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

/// Opens URLs outside the app. [PluginUrlOpener] in apps; a fake in tests.
abstract interface class UrlOpener {
  /// Opens [uri] in a native (non-browser) app. False when none handles it.
  Future<bool> openInApp(Uri uri);

  /// Opens [uri] with whatever handles it outside the app (browser for
  /// web links; the owning app for custom schemes).
  Future<bool> openInBrowser(Uri uri);

  /// Whether some app can open [uri] (needs `LSApplicationQueriesSchemes`
  /// on iOS / `<queries>` on Android for custom schemes).
  Future<bool> canOpen(Uri uri);
}

final class PluginUrlOpener implements UrlOpener {
  const PluginUrlOpener();

  @override
  Future<bool> openInApp(Uri uri) async {
    try {
      return await ul.launchUrl(
        uri,
        mode: ul.LaunchMode.externalNonBrowserApplication,
      );
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> openInBrowser(Uri uri) async {
    try {
      return await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> canOpen(Uri uri) async {
    try {
      return await ul.canLaunchUrl(uri);
    } on Object {
      return false;
    }
  }
}

/// Travel modes of the Google Maps URL API.
const directionsTravelModes = ['driving', 'walking', 'bicycling', 'transit'];

/// Builds a Google Maps directions URL (Maps URLs, `api=1`) to a specific
/// destination: coordinates and/or a Place ID. Returns null when the input
/// is not a valid, specific destination. No API key is involved.
Uri? googleMapsDirectionsUrl({
  double? latitude,
  double? longitude,
  String? placeId,
  String? name,
  String? travelMode,
}) {
  final hasCoords = latitude != null && longitude != null;
  if (hasCoords &&
      (latitude.abs() > 90 ||
          longitude.abs() > 180 ||
          latitude.isNaN ||
          longitude.isNaN)) {
    return null;
  }
  if (placeId != null &&
      !RegExp(r'^[A-Za-z0-9_-]{10,300}$').hasMatch(placeId)) {
    return null;
  }
  if (travelMode != null && !directionsTravelModes.contains(travelMode)) {
    return null;
  }
  // `destination_place_id` requires `destination`; coordinates are the
  // most precise destination text, then the place name.
  final destination = hasCoords
      ? '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}'
      : (placeId != null && name != null && name.trim().isNotEmpty)
      ? name.trim()
      : null;
  if (destination == null) return null;
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
    'destination_place_id': ?placeId,
    'travelmode': ?travelMode,
  });
}

/// `maps.open_directions` v1: opens directions to one specific place in
/// the native maps app (Google Maps / Apple Maps handle the universal
/// link), falling back to the browser. Output: the URL and where it opened.
final class DirectionsTool implements ClientToolExecutor {
  DirectionsTool({this.opener = const PluginUrlOpener()});

  static const id = 'maps.open_directions';

  final UrlOpener opener;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Open directions',
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'place_id': {'type': 'string'},
        'name': {'type': 'string'},
        'latitude': {'type': 'number', 'minimum': -90, 'maximum': 90},
        'longitude': {'type': 'number', 'minimum': -180, 'maximum': 180},
        'travel_mode': {'type': 'string', 'enum': directionsTravelModes},
      },
    },
    outputSchema: {
      'type': 'object',
      'required': ['url', 'opened_in'],
      'properties': {
        'url': {'type': 'string'},
        'opened_in': {
          'type': 'string',
          'enum': ['app', 'browser'],
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
    final url = googleMapsDirectionsUrl(
      latitude: (a['latitude'] as num?)?.toDouble(),
      longitude: (a['longitude'] as num?)?.toDouble(),
      placeId: a['place_id'] as String?,
      name: a['name'] as String?,
      travelMode: a['travel_mode'] as String?,
    );
    if (url == null) {
      return ClientToolResult.failure(
        request,
        const ClientToolError(
          ClientToolErrorCode.invalidArguments,
          'a specific destination (coordinates or place_id + name) is required',
        ),
      );
    }
    if (await opener.openInApp(url)) {
      return ClientToolResult.success(request, {
        'url': url.toString(),
        'opened_in': 'app',
      });
    }
    if (await opener.openInBrowser(url)) {
      return ClientToolResult.success(request, {
        'url': url.toString(),
        'opened_in': 'browser',
      });
    }
    return ClientToolResult.failure(
      request,
      const ClientToolError(
        ClientToolErrorCode.unsupported,
        'no app or browser could open the link',
        retryable: true,
      ),
    );
  }
}
