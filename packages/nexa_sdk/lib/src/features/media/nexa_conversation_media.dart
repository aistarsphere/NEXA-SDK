import 'package:flutter/foundation.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';

/// Host switches for client device tools. Each can only be turned **off**;
/// assistant-initiated runs additionally need `toolCalling` granted by the
/// backend, and every run asks the user first.
@immutable
final class NexaClientToolOptions {
  const NexaClientToolOptions({
    this.location = true,
    this.camera = true,
    this.photoLibrary = true,
    this.directions = true,
    this.files = true,
    this.filePicker,
    this.network = true,
    this.wifi = true,
    this.browser = true,
    this.browserAllowedHosts,
    this.share = true,
    this.settings = true,
    this.microphoneSample = true,
    this.microphoneRecorder,
    this.declarationPriority,
    this.apps = const [],
    this.extraTools = const [],
    this.toolOverrides = const [],
    this.networkPlatform,
    this.shareSheet,
    this.locationPlatform,
    this.urlOpener,
    this.cameraSessionFactory,
    this.imagePicker,
    this.mediaStore,
    this.onOpenSettings,
    this.resultSink,
    this.onApproval,
  });

  /// `device.location.get_current`.
  final bool location;

  /// `device.camera.capture` and "Take a photo".
  final bool camera;

  /// "Choose from library".
  final bool photoLibrary;

  /// `maps.open_directions` (Google Maps URL, native app or browser).
  final bool directions;

  /// "Choose a file" (PDF, text, Office; ≤ 10 MB) and `device.files.pick`.
  final bool files;
  final NexaFilePicker? filePicker;

  /// `device.network.get_status`.
  final bool network;

  /// `device.wifi.get_current_info` (SSID only where the OS allows).
  final bool wifi;

  /// `device.browser.open_url`, optionally limited to these hosts.
  final bool browser;
  final Set<String>? browserAllowedHosts;

  /// `device.share.open`.
  final bool share;

  /// `device.settings.open`.
  final bool settings;

  /// `device.microphone.record_sample` (voice identity). Records only after
  /// the user approves the call and taps "Start recording".
  final bool microphoneSample;

  /// Test seam for the sample recorder (default: the `record` plugin).
  final NexaMicrophoneRecorder Function()? microphoneRecorder;

  /// Which device tools to declare first when more are enabled than the
  /// gateway accepts in `client_tools` (8). Null: the SDK default order.
  final List<String>? declarationPriority;

  /// Apps the assistant may open (`device.app.open`,
  /// `device.apps.query_supported`); empty disables both.
  final List<NexaAppTarget> apps;

  /// Host tools registered next to the built-ins.
  final List<ClientToolExecutor> extraTools;

  /// Host replacements for built-in tools (same tool id).
  final List<ClientToolExecutor> toolOverrides;

  final NexaNetworkPlatform? networkPlatform;
  final NexaShareSheet? shareSheet;

  final UrlOpener? urlOpener;

  /// Test seams (default: the real plugins).
  final LocationPlatform? locationPlatform;
  final NexaCameraSessionFactory? cameraSessionFactory;
  final NexaImagePicker? imagePicker;
  final NexaMediaStore? mediaStore;

  /// Opens the app's page in system settings after a denial.
  final VoidCallback? onOpenSettings;

  /// Replaces the SDK's inline approval (tool card "Allow once" / "Not
  /// now") with the host's own flow. Must still ask the user.
  final ClientToolApproval? onApproval;

  /// Where tool results go. Default: nowhere (the backend has no
  /// client-tool result API yet), so results are marked not delivered.
  final ClientToolResultSink? resultSink;
}

/// Delivers client tool results / attachments to the backend.
abstract interface class ClientToolResultSink {
  /// Whether the backend accepts client tool results at all.
  bool get acceptsResults;

  /// Whether the backend accepts image attachments.
  bool get acceptsAttachments;

  /// Sends [result]; returns true when the backend confirmed it.
  Future<bool> deliver(ClientToolResult result);
}

/// The current backend: no client-tool or attachment API. Honest default.
final class UnavailableClientToolResultSink implements ClientToolResultSink {
  const UnavailableClientToolResultSink();

  @override
  bool get acceptsResults => false;

  @override
  bool get acceptsAttachments => false;

  @override
  Future<bool> deliver(ClientToolResult result) async => false;
}

/// Non-text conversation content (attachments, tool runs) shared by the
/// chat and live voice views of one client. In memory; files live in the
/// [NexaMediaStore].
final class NexaConversationMedia extends ChangeNotifier {
  final List<NexaConversationItem> _items = [];

  /// The image the next message refers to ("Ask about this image").
  final ValueNotifier<NexaAttachment?> reference = ValueNotifier(null);

  List<NexaConversationItem> get items => List.unmodifiable(_items);

  Iterable<NexaAttachmentItem> get attachments =>
      _items.whereType<NexaAttachmentItem>();

  /// The most recent places result (what "the second one" refers to).
  NexaPlacesItem? get latestPlaces =>
      _items.whereType<NexaPlacesItem>().lastOrNull;

  /// Place number [ordinal] (1-based) of the latest places result.
  NexaPlace? placeAt(int ordinal) => latestPlaces?.placeAt(ordinal);

  /// The place the user picked in the latest result (tap on a place).
  String? selectedPlaceId;

  void selectPlace(NexaPlace place) {
    selectedPlaceId = place.placeId;
    notifyListeners();
  }

  /// Context the next message should carry so the backend can resolve
  /// "the second restaurant" (contract: `context.places`).
  Map<String, Object?>? get placesContext {
    final latest = latestPlaces;
    if (latest == null || latest.result.places.isEmpty) return null;
    final selected = selectedPlaceId;
    return {
      'result_id': latest.result.resultId,
      'places': latest.ordinals,
      if (selected != null &&
          latest.result.places.any((p) => p.placeId == selected))
        'selected_place_id': selected,
    };
  }

  /// Adds a places result, or updates the item of the same result id (e.g.
  /// loading → ok).
  void putPlaces(NexaPlacesResult result, {NexaItemSurface? surface}) {
    final i = _items.indexWhere(
      (e) => e is NexaPlacesItem && e.result.resultId == result.resultId,
    );
    if (i >= 0) {
      final old = _items[i];
      _items[i] = NexaPlacesItem(
        id: old.id,
        createdAt: old.createdAt,
        result: result,
        surface: old.surface,
      );
    } else {
      _items.add(
        NexaPlacesItem(
          id: 'places_${result.resultId}',
          createdAt: DateTime.now().toUtc(),
          result: result,
          surface: surface ?? NexaItemSurface.chat,
        ),
      );
    }
    notifyListeners();
  }

  void add(NexaConversationItem item) {
    _items.add(item);
    notifyListeners();
  }

  /// Replaces the item with the same id.
  void replace(NexaConversationItem item) {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i < 0) return;
    _items[i] = item;
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Starts a new conversation (items stay in history, not on screen).
  void clear() {
    _items.clear();
    reference.value = null;
    notifyListeners();
  }

  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }
}
