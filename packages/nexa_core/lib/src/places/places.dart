import 'package:meta/meta.dart';

/// Contract of nearby-place results produced by the backend's server tool
/// `places.search_nearby` (proposed: `docs/contracts/nexa-client-tools.proposed.md`).
/// The place provider (and its API key) lives on AWS; Flutter only renders.
const String placesContractV1 = 'nexa.places.v1';

@immutable
final class NexaPlace {
  const NexaPlace({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
    this.rating,
    this.ratingCount,
    this.distanceMeters,
    this.address,
    this.openNow,
  });

  /// Throws [FormatException] when a required field is missing/invalid.
  factory NexaPlace.fromJson(Map<String, Object?> json) {
    final id = json['place_id'];
    final name = json['name'];
    final loc = json['location'];
    if (id is! String || id.isEmpty) throw const FormatException('place_id');
    if (name is! String || name.isEmpty) throw const FormatException('name');
    if (loc is! Map) throw const FormatException('location');
    final lat = loc['lat'];
    final lng = loc['lng'];
    if (lat is! num || lng is! num || lat.abs() > 90 || lng.abs() > 180) {
      throw const FormatException('location.lat/lng');
    }
    final rating = json['rating'];
    final count = json['user_rating_count'];
    final distance = json['distance_m'];
    return NexaPlace(
      placeId: id,
      name: name,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      category: json['category'] as String?,
      rating: rating is num && rating >= 0 && rating <= 5
          ? rating.toDouble()
          : null,
      ratingCount: count is int && count >= 0 ? count : null,
      distanceMeters: distance is num && distance >= 0
          ? distance.toDouble()
          : null,
      address: json['address'] as String?,
      openNow: json['open_now'] as bool?,
    );
  }

  /// Provider place id (e.g. a Google Place ID), kept for follow-ups and
  /// directions.
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final String? category;

  /// 0..5 when the provider has one.
  final double? rating;
  final int? ratingCount;

  /// From the search origin, computed by the backend when it knows it.
  final double? distanceMeters;

  /// Address text from the provider (never invented on the device).
  final String? address;
  final bool? openNow;

  Map<String, Object?> toJson() => {
    'place_id': placeId,
    'name': name,
    'location': {'lat': latitude, 'lng': longitude},
    if (category != null) 'category': category,
    if (rating != null) 'rating': rating,
    if (ratingCount != null) 'user_rating_count': ratingCount,
    if (distanceMeters != null) 'distance_m': distanceMeters,
    if (address != null) 'address': address,
    if (openNow != null) 'open_now': openNow,
  };
}

/// Status of a places result.
enum NexaPlacesStatus {
  /// Search running (backend `server_tool_started`).
  loading,
  ok,

  /// The search ran and found nothing.
  zeroResults,

  /// The search needs the device location and it was denied.
  locationDenied,
  error,
}

@immutable
final class NexaPlacesResult {
  const NexaPlacesResult({
    required this.resultId,
    required this.status,
    this.places = const [],
    this.query,
    this.originLatitude,
    this.originLongitude,
    this.attribution,
    this.errorCode,
    this.retryable = false,
  });

  /// Parses a `places.search_nearby` result. Invalid places are skipped
  /// (never patched up); an invalid envelope throws [FormatException].
  factory NexaPlacesResult.fromJson(Map<String, Object?> json) {
    if (json['contract'] != placesContractV1) {
      throw FormatException('unsupported contract ${json['contract']}');
    }
    final id = json['result_id'];
    if (id is! String || id.isEmpty) throw const FormatException('result_id');
    final status = switch (json['status']) {
      'ok' => NexaPlacesStatus.ok,
      'zero_results' => NexaPlacesStatus.zeroResults,
      'location_denied' => NexaPlacesStatus.locationDenied,
      'loading' => NexaPlacesStatus.loading,
      'error' => NexaPlacesStatus.error,
      _ => throw FormatException('status ${json['status']}'),
    };
    final places = <NexaPlace>[];
    for (final p in (json['places'] as List?) ?? const []) {
      if (p is! Map) continue;
      try {
        places.add(NexaPlace.fromJson(p.cast<String, Object?>()));
      } on FormatException {
        continue;
      }
    }
    final origin = json['origin'];
    final error = json['error'];
    return NexaPlacesResult(
      resultId: id,
      status: status == NexaPlacesStatus.ok && places.isEmpty
          ? NexaPlacesStatus.zeroResults
          : status,
      places: List.unmodifiable(places),
      query: json['query'] as String?,
      originLatitude: origin is Map
          ? (origin['lat'] as num?)?.toDouble()
          : null,
      originLongitude: origin is Map
          ? (origin['lng'] as num?)?.toDouble()
          : null,
      attribution: json['attribution'] as String?,
      errorCode: error is Map ? error['code'] as String? : null,
      retryable: error is Map && error['retryable'] == true,
    );
  }

  final String resultId;
  final NexaPlacesStatus status;
  final List<NexaPlace> places;
  final String? query;
  final double? originLatitude;
  final double? originLongitude;

  /// Provider attribution to display (required by most providers).
  final String? attribution;
  final String? errorCode;
  final bool retryable;
}
