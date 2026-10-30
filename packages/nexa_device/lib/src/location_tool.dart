import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:nexa_core/nexa_core.dart';

/// OS permission state for location, as the tool sees it.
enum LocationPermissionState { notDetermined, denied, blocked, granted }

/// One location fix.
final class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    this.altitudeMeters,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final double? altitudeMeters;
  final bool isMocked;
}

/// Thrown by [LocationPlatform.currentFix].
final class LocationFixException implements Exception {
  const LocationFixException(this.code);
  final ClientToolErrorCode code;
}

/// Device location access. [GeolocatorLocationPlatform] in apps; a fake in
/// tests.
abstract interface class LocationPlatform {
  Future<bool> serviceEnabled();
  Future<LocationPermissionState> permission();
  Future<LocationPermissionState> requestPermission();

  /// A single fix (no tracking). Throws [LocationFixException].
  Future<LocationFix> currentFix({
    required bool highAccuracy,
    required Duration timeout,
  });

  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

final class GeolocatorLocationPlatform implements LocationPlatform {
  const GeolocatorLocationPlatform();

  @override
  Future<bool> serviceEnabled() => geo.Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionState> permission() async =>
      _map(await geo.Geolocator.checkPermission());

  @override
  Future<LocationPermissionState> requestPermission() async =>
      _map(await geo.Geolocator.requestPermission());

  static LocationPermissionState _map(geo.LocationPermission p) => switch (p) {
    geo.LocationPermission.always ||
    geo.LocationPermission.whileInUse => LocationPermissionState.granted,
    geo.LocationPermission.deniedForever => LocationPermissionState.blocked,
    geo.LocationPermission.denied => LocationPermissionState.denied,
    geo.LocationPermission.unableToDetermine =>
      LocationPermissionState.notDetermined,
  };

  @override
  Future<LocationFix> currentFix({
    required bool highAccuracy,
    required Duration timeout,
  }) async {
    try {
      final p = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(
          accuracy: highAccuracy
              ? geo.LocationAccuracy.high
              : geo.LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      return LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyMeters: p.accuracy,
        timestamp: p.timestamp.toUtc(),
        altitudeMeters: p.altitude,
        isMocked: p.isMocked,
      );
    } on TimeoutException {
      throw const LocationFixException(ClientToolErrorCode.timeout);
    } on geo.LocationServiceDisabledException {
      throw const LocationFixException(ClientToolErrorCode.serviceDisabled);
    } on geo.PermissionDeniedException {
      throw const LocationFixException(ClientToolErrorCode.permissionDenied);
    }
  }

  @override
  Future<bool> openAppSettings() => geo.Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();
}

/// `device.location.get_current` v1: one current position after user
/// approval. Never tracks, never runs at start-up, never invents an
/// address (no reverse geocoding provider is configured, so the output has
/// no `address`).
final class LocationTool implements ClientToolExecutor {
  LocationTool({this.platform = const GeolocatorLocationPlatform()});

  static const id = 'device.location.get_current';

  final LocationPlatform platform;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Current location',
    requiredPermissions: {ClientToolPermission.location},
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'accuracy': {
          'type': 'string',
          'enum': ['high', 'balanced'],
        },
        'timeout_ms': {'type': 'integer', 'minimum': 1000, 'maximum': 30000},
        'reason': {'type': 'string'},
      },
    },
    outputSchema: {
      'type': 'object',
      'required': ['latitude', 'longitude', 'accuracy_m', 'timestamp'],
      'properties': {
        'latitude': {'type': 'number'},
        'longitude': {'type': 'number'},
        'accuracy_m': {'type': 'number'},
        'altitude_m': {'type': 'number'},
        'timestamp': {'type': 'string', 'format': 'date-time'},
        'is_mocked': {'type': 'boolean'},
      },
    },
  );

  @override
  Future<ClientToolAvailability> availability() async {
    if (!await platform.serviceEnabled()) {
      return ClientToolAvailability.serviceDisabled;
    }
    return switch (await platform.permission()) {
      LocationPermissionState.granted => ClientToolAvailability.available,
      LocationPermissionState.notDetermined =>
        ClientToolAvailability.needsPermission,
      LocationPermissionState.denied => ClientToolAvailability.permissionDenied,
      LocationPermissionState.blocked =>
        ClientToolAvailability.permissionBlocked,
    };
  }

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    ClientToolResult fail(
      ClientToolErrorCode code, {
      bool retryable = false,
      bool settings = false,
    }) => ClientToolResult.failure(
      request,
      ClientToolError(
        code,
        code.name,
        retryable: retryable,
        canOpenSettings: settings,
      ),
    );

    if (!await platform.serviceEnabled()) {
      return fail(
        ClientToolErrorCode.serviceDisabled,
        retryable: true,
        settings: true,
      );
    }
    var permission = await platform.permission();
    if (permission == LocationPermissionState.notDetermined ||
        permission == LocationPermissionState.denied) {
      onPhase(ClientToolRunPhase.awaitingPermission);
      permission = await platform.requestPermission();
      onPhase(ClientToolRunPhase.running);
    }
    switch (permission) {
      case LocationPermissionState.blocked:
        return fail(ClientToolErrorCode.permissionBlocked, settings: true);
      case LocationPermissionState.denied ||
          LocationPermissionState.notDetermined:
        return fail(ClientToolErrorCode.permissionDenied, retryable: true);
      case LocationPermissionState.granted:
        break;
    }
    final timeoutMs = request.arguments['timeout_ms'] as int? ?? 15000;
    try {
      final fix = await platform.currentFix(
        highAccuracy: request.arguments['accuracy'] != 'balanced',
        timeout: Duration(milliseconds: timeoutMs),
      );
      return ClientToolResult.success(request, {
        'latitude': fix.latitude,
        'longitude': fix.longitude,
        'accuracy_m': fix.accuracyMeters,
        'altitude_m': ?fix.altitudeMeters,
        'timestamp': fix.timestamp.toUtc().toIso8601String(),
        'is_mocked': fix.isMocked,
      });
    } on LocationFixException catch (e) {
      return fail(
        e.code,
        retryable: e.code != ClientToolErrorCode.permissionBlocked,
        settings: e.code == ClientToolErrorCode.serviceDisabled,
      );
    }
  }
}
