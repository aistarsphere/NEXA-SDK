import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_surface_controller.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_surface_view.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Inline card container (chat timeline).
class NexaSurfaceCard extends StatelessWidget {
  const NexaSurfaceCard({
    required this.surfaceId,
    required this.controller,
    this.onRetry,
    super.key,
  });

  final String surfaceId;
  final NexaSurfaceController controller;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material (not a colored box) so choice ripples stay visible.
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: NexaSurfaceView(
          surfaceId: surfaceId,
          controller: controller,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

/// Collapsed by default; expands in place.
class NexaSurfaceExpandable extends StatelessWidget {
  const NexaSurfaceExpandable({
    required this.surfaceId,
    required this.controller,
    super.key,
  });

  final String surfaceId;
  final NexaSurfaceController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.surface(surfaceId);
    return Card(
      child: ExpansionTile(
        key: Key('nexa_surface_expandable_$surfaceId'),
        title: Text(s?.title ?? s?.fallbackText ?? ''),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          NexaSurfaceView(surfaceId: surfaceId, controller: controller),
        ],
      ),
    );
  }
}

/// Presents surface [surfaceId] in its own [NexaSurface.presentation]
/// (or [as]). Overlays open on the host navigator and never end a live
/// voice call underneath. Theme surfaces cancel an unapplied preview when
/// dismissed.
Future<void> showNexaSurface(
  BuildContext context,
  NexaSurfaceController controller,
  String surfaceId, {
  NexaPresentation? as,
}) async {
  final s = controller.surface(surfaceId);
  if (s == null) return;
  final presentation = as ?? s.presentation;
  Widget body(BuildContext ctx) => NexaSurfaceView(
    surfaceId: surfaceId,
    controller: controller,
    onClose: () => Navigator.of(ctx).maybePop(),
  );
  switch (presentation) {
    case NexaPresentation.bottomSheet:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => nexaScoped(
          context,
          SafeArea(
            child: SingleChildScrollView(
              key: const Key('nexa_surface_sheet'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: body(sheetContext),
            ),
          ),
        ),
      );
    case NexaPresentation.modal:
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => nexaScoped(
          context,
          Dialog(
            key: const Key('nexa_surface_modal'),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: body(dialogContext),
            ),
          ),
        ),
      );
    case NexaPresentation.fullScreen:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (routeContext) => nexaScoped(
            context,
            Scaffold(
              key: const Key('nexa_surface_full_screen'),
              appBar: AppBar(title: Text(s.title ?? '')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: body(routeContext),
              ),
            ),
          ),
        ),
      );
    case NexaPresentation.floatingPanel:
      final done = Completer<void>();
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => nexaScoped(
          context,
          _FloatingPanel(
            surfaceId: surfaceId,
            controller: controller,
            onDismiss: () {
              entry.remove();
              if (!done.isCompleted) done.complete();
            },
          ),
        ),
      );
      Overlay.of(context).insert(entry);
      await done.future;
    case NexaPresentation.inlineCard ||
        NexaPresentation.expandable ||
        NexaPresentation.voiceCompanion:
      // Rendered in place by the timeline / voice page.
      return;
  }
  if (s.category == NexaSurfaceCategory.themesAppearance) {
    await controller.host.theme?.cancelPreview();
  }
}

class _FloatingPanel extends StatelessWidget {
  const _FloatingPanel({
    required this.surfaceId,
    required this.controller,
    required this.onDismiss,
  });

  final String surfaceId;
  final NexaSurfaceController controller;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 24 + MediaQuery.paddingOf(context).bottom,
      child: Material(
        key: const Key('nexa_surface_floating'),
        elevation: 6,
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: NexaSurfaceView(
                  surfaceId: surfaceId,
                  controller: controller,
                  onClose: onDismiss,
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: IconButton(
                  tooltip: l10n.duiDismiss,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rich content during a live call: expand, minimize or dismiss while the
/// call (and its mic/audio controls below) keeps running.
class NexaSurfaceCompanion extends StatefulWidget {
  const NexaSurfaceCompanion({
    required this.surfaceId,
    required this.controller,
    required this.onDismiss,
    super.key,
  });

  final String surfaceId;
  final NexaSurfaceController controller;
  final VoidCallback onDismiss;

  @override
  State<NexaSurfaceCompanion> createState() => _NexaSurfaceCompanionState();
}

class _NexaSurfaceCompanionState extends State<NexaSurfaceCompanion> {
  bool _minimized = false;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final s = widget.controller.surface(widget.surfaceId);
    if (s == null) return const SizedBox.shrink();
    return Padding(
      key: Key('nexa_surface_companion_${widget.surfaceId}'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    s.title ?? s.fallbackText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  key: const Key('nexa_companion_toggle'),
                  tooltip: _minimized ? l10n.duiExpand : l10n.duiMinimize,
                  onPressed: () => setState(() => _minimized = !_minimized),
                  icon: Icon(
                    _minimized
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ),
                IconButton(
                  key: const Key('nexa_companion_open'),
                  tooltip: l10n.duiOpen,
                  onPressed: () => showNexaSurface(
                    context,
                    widget.controller,
                    widget.surfaceId,
                    as: NexaPresentation.fullScreen,
                  ),
                  icon: const Icon(Icons.open_in_full_rounded),
                ),
                IconButton(
                  key: const Key('nexa_companion_dismiss'),
                  tooltip: l10n.duiDismiss,
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (!_minimized)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.38,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: NexaSurfaceView(
                    surfaceId: widget.surfaceId,
                    controller: widget.controller,
                    compact: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
