import 'package:nexa_core/src/tools/tool_result.dart';

/// Outcome of validating a structured tool payload.
sealed class ToolResultValidation {
  const ToolResultValidation();
}

/// Payload is well-formed and semantically acceptable.
final class ValidToolResult extends ToolResultValidation {
  const ValidToolResult(this.result);
  final ToolResult result;
}

/// Payload was rejected. [reason] is developer-facing. The SDK renders a
/// generic error card instead of the untrusted payload.
final class InvalidToolResult extends ToolResultValidation {
  const InvalidToolResult(this.reason, {this.path});
  final String reason;
  final String? path;
}

/// Validates incoming structured data **before** rendering.
///
/// Two layers:
/// 1. Shape: JSON must deserialise into a known [ToolResult] variant.
/// 2. Semantics: ranges, URI schemes, non-empty collections, option
///    references inside forms, etc.
///
/// Never throws. A failure becomes an [InvalidToolResult] which callers map to
/// `ToolResult.error` so the conversation stays consistent.
final class ToolResultValidator {
  const ToolResultValidator({this.allowedUriSchemes = const {'https'}});

  /// URI schemes permitted in media and image fields. Defaults to https only.
  final Set<String> allowedUriSchemes;

  /// Max items rendered per list result; longer lists are rejected rather
  /// than silently truncated so the backend contract stays honest.
  static const maxListItems = 50;

  /// Parses and validates [json].
  ToolResultValidation parse(Object? json) {
    if (json is! Map<String, Object?>) {
      return const InvalidToolResult('Tool result must be a JSON object.');
    }
    final kind = json['kind'];
    if (kind is! String || kind.isEmpty) {
      return const InvalidToolResult('Missing "kind".', path: 'kind');
    }
    final ToolResult result;
    try {
      result = ToolResult.fromJson(json);
    } on Object catch (error) {
      return InvalidToolResult('Malformed "$kind" payload: $error');
    }
    return validate(result);
  }

  /// Semantic validation of an already-typed result.
  ToolResultValidation validate(ToolResult result) {
    final problem = switch (result) {
      TextToolResult(:final text) =>
        text.trim().isEmpty ? 'text is empty' : null,
      RichCardToolResult(:final card) => _card(card),
      RestaurantsToolResult(:final items) => _restaurants(items),
      MapRouteToolResult(:final route) => _route(route),
      WeatherToolResult(:final weather) => _weather(weather),
      MediaToolResult(:final items) => _media(items),
      FormToolResult(:final form) => _form(form),
      SelectionToolResult(:final selection) => _selection(selection),
      ConfirmationToolResult(:final confirmation) => _confirmation(
        confirmation,
      ),
      ErrorToolResult(:final error) =>
        error.message.trim().isEmpty ? 'error.message is empty' : null,
    };
    return problem == null
        ? ValidToolResult(result)
        : InvalidToolResult(problem);
  }

  /// Converts a validation outcome into a renderable result, substituting an
  /// error card for rejected payloads.
  ToolResult toRenderable(ToolResultValidation validation) =>
      switch (validation) {
        ValidToolResult(:final result) => result,
        InvalidToolResult(:final reason) => ToolResult.error(
          error: ToolError(code: 'invalid_tool_result', message: reason),
        ),
      };

  String? _uri(Uri? uri, String path) {
    if (uri == null) return null;
    if (!allowedUriSchemes.contains(uri.scheme)) {
      return '$path uses disallowed scheme "${uri.scheme}"';
    }
    return null;
  }

  String? _card(RichCard card) {
    if (card.title.trim().isEmpty) return 'card.title is empty';
    final ids = card.actions.map((a) => a.id).toSet();
    if (ids.length != card.actions.length) {
      return 'card.actions ids must be unique';
    }
    return _uri(card.imageUri, 'card.imageUri');
  }

  String? _restaurants(List<RestaurantResult> items) {
    if (items.isEmpty) return 'restaurants.items is empty';
    if (items.length > maxListItems) {
      return 'restaurants.items exceeds $maxListItems';
    }
    for (final (i, r) in items.indexed) {
      if (r.name.trim().isEmpty) return 'items[$i].name is empty';
      final rating = r.rating;
      if (rating != null && (rating < 0 || rating > 5)) {
        return 'items[$i].rating out of range 0..5';
      }
      final tier = r.priceTier;
      if (tier != null && (tier < 1 || tier > 4)) {
        return 'items[$i].priceTier out of range 1..4';
      }
      final uriProblem = _uri(r.imageUri, 'items[$i].imageUri');
      if (uriProblem != null) return uriProblem;
    }
    return null;
  }

  String? _point(GeoPoint p, String path) {
    if (p.latitude < -90 || p.latitude > 90) {
      return '$path.latitude out of range';
    }
    if (p.longitude < -180 || p.longitude > 180) {
      return '$path.longitude out of range';
    }
    return null;
  }

  String? _route(MapRoute route) {
    return _point(route.origin, 'route.origin') ??
        _point(route.destination, 'route.destination') ??
        (route.distanceMeters != null && route.distanceMeters! < 0
            ? 'route.distanceMeters is negative'
            : null);
  }

  String? _weather(WeatherData w) {
    if (w.locationName.trim().isEmpty) return 'weather.locationName is empty';
    if (w.temperatureC < -100 || w.temperatureC > 70) {
      return 'weather.temperatureC is implausible';
    }
    final humidity = w.humidityPercent;
    if (humidity != null && (humidity < 0 || humidity > 100)) {
      return 'weather.humidityPercent out of range';
    }
    return null;
  }

  String? _media(List<MediaItem> items) {
    if (items.isEmpty) return 'media.items is empty';
    if (items.length > maxListItems) return 'media.items exceeds $maxListItems';
    for (final (i, m) in items.indexed) {
      final problem =
          _uri(m.uri, 'items[$i].uri') ??
          _uri(m.thumbnailUri, 'items[$i].thumbnailUri');
      if (problem != null) return problem;
    }
    return null;
  }

  String? _form(FormSpec form) {
    if (form.fields.isEmpty) return 'form.fields is empty';
    final ids = form.fields.map((f) => f.id).toSet();
    if (ids.length != form.fields.length) {
      return 'form.fields ids must be unique';
    }
    for (final f in form.fields) {
      if (f.type == FormFieldType.select && f.options.isEmpty) {
        return 'form field "${f.id}" is select but has no options';
      }
    }
    return null;
  }

  String? _selection(SelectionSpec s) {
    if (s.options.isEmpty) return 'selection.options is empty';
    final ids = s.options.map((o) => o.id).toSet();
    if (ids.length != s.options.length) {
      return 'selection.options ids must be unique';
    }
    if (s.minSelections < 0) return 'selection.minSelections is negative';
    final max = s.maxSelections;
    if (max != null && max < s.minSelections) {
      return 'selection.maxSelections < minSelections';
    }
    if (!s.multiSelect && (max ?? 1) > 1) {
      return 'single selection cannot allow more than one choice';
    }
    return null;
  }

  String? _confirmation(ConfirmationSpec c) {
    if (c.title.trim().isEmpty) return 'confirmation.title is empty';
    if (c.description.trim().isEmpty) {
      return 'confirmation.description is empty';
    }
    return null;
  }
}
