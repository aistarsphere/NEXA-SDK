import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_ui_view.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_audio_player.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_calls.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// User-facing title of a contract tool (never the raw name).
String labeebToolTitle(NexaLocalizations l10n, String tool) => switch (tool) {
  LabeebTools.location => l10n.tcToolLocation,
  LabeebTools.camera => l10n.tcToolCamera,
  LabeebTools.photoPick => l10n.tcToolPhoto,
  LabeebTools.filePick => l10n.tcToolFile,
  LabeebTools.directions => l10n.tcToolDirections,
  LabeebTools.openUrl => l10n.tcToolOpenUrl,
  LabeebTools.network => l10n.tcToolNetwork,
  LabeebTools.share => l10n.tcToolShare,
  LabeebTools.openSettings => l10n.tcToolSettings,
  LabeebTools.themeApply => l10n.tcToolTheme,
  LabeebTools.themeReset => l10n.tcToolThemeReset,
  LabeebTools.placesNearby || LabeebTools.placesText => l10n.tcToolPlaces,
  LabeebTools.vision => l10n.tcToolVision,
  LabeebTools.imageGenerate => l10n.tcToolImageGenerate,
  LabeebTools.imageEdit => l10n.tcToolImageEdit,
  LabeebTools.ocr => l10n.tcToolOcr,
  LabeebTools.fileRead => l10n.tcToolFileRead,
  LabeebTools.fileCreate => l10n.tcToolFileCreate,
  LabeebTools.webSearch => l10n.tcToolWeb,
  LabeebTools.news => l10n.tcToolNews,
  LabeebTools.sports => l10n.tcToolSports,
  LabeebTools.video => l10n.tcToolVideo,
  LabeebTools.themePalettes => l10n.tcToolPalettes,
  LabeebTools.jobsStatus || LabeebTools.jobsCancel => l10n.tcToolJobs,
  LabeebTools.recordSample => l10n.recTitle,
  // Tool families: new tools of a known group need no SDK change.
  _ when tool.startsWith('voice.profile.') => l10n.tcToolVoiceProfile,
  _ when tool.startsWith('jira.') => l10n.tcToolJira,
  _ => l10n.tcToolOther,
};

IconData _toolIcon(String tool) => switch (tool) {
  LabeebTools.location ||
  LabeebTools.directions ||
  LabeebTools.placesNearby ||
  LabeebTools.placesText => Icons.place_outlined,
  LabeebTools.camera => Icons.photo_camera_outlined,
  LabeebTools.photoPick ||
  LabeebTools.vision ||
  LabeebTools.imageGenerate ||
  LabeebTools.imageEdit => Icons.image_outlined,
  LabeebTools.filePick ||
  LabeebTools.fileRead ||
  LabeebTools.fileCreate ||
  LabeebTools.ocr => Icons.description_outlined,
  LabeebTools.openUrl || LabeebTools.webSearch => Icons.travel_explore,
  LabeebTools.network => Icons.wifi_rounded,
  LabeebTools.share => Icons.ios_share_rounded,
  LabeebTools.openSettings => Icons.settings_outlined,
  LabeebTools.themeApply ||
  LabeebTools.themeReset ||
  LabeebTools.themePalettes => Icons.palette_outlined,
  LabeebTools.news => Icons.article_outlined,
  LabeebTools.sports => Icons.sports_soccer_outlined,
  LabeebTools.video => Icons.play_circle_outline,
  LabeebTools.recordSample => Icons.mic_none_rounded,
  _ when tool.startsWith('voice.profile.') => Icons.record_voice_over_outlined,
  _ when tool.startsWith('jira.') => Icons.view_kanban_outlined,
  _ => Icons.auto_awesome_outlined,
};

/// The message for a contract error code (provider/GPU blocks are said
/// plainly; nothing is faked).
String labeebErrorText(NexaLocalizations l10n, String code) => switch (code) {
  'requires_configuration' ||
  'provider_unavailable' ||
  'provider_unreachable' ||
  'provider_credentials_rejected' ||
  'places_api_not_enabled' => l10n.tcProviderBlocked,
  'provider_rate_limited' || 'rate_limited' => l10n.tcRateLimited,
  'gpu_busy' || 'gpu_capacity' => l10n.tcGpuBusy,
  'gpu_unavailable' ||
  'gpu_rejected' ||
  'model_not_ready' ||
  'no_model_selected' => l10n.tcGpuBlocked,
  // Operator action needed (GPU, app feature or token scope).
  'gpu_not_permitted' || 'forbidden' || 'tools_disabled' => l10n.tcNotEnabled,
  'tool_call_closed' || 'not_awaiting_approval' => l10n.tcClosed,
  'cancelled' => l10n.tcCancelled,
  'domain_not_allowed' => l10n.tcDomainNotAllowed,
  'not_readable' => l10n.tcNotReadable,
  'job_not_found' => l10n.tcJobNotFound,
  'invalid_arguments' ||
  'unknown_tool' ||
  'jira_bad_request' ||
  'jira_no_sprints' => l10n.tcCouldNotRun,
  // Company admin action (organization's Jira connection).
  'jira_not_connected' || 'jira_site_not_selected' => l10n.tcJiraNotConnected,
  'jira_reconnect_required' => l10n.tcJiraReconnect,
  'jira_forbidden' => l10n.tcJiraForbidden,
  'jira_not_found' => l10n.tcJiraNotFound,
  'unsupported_media_type' || 'asset_too_large' => l10n.tcUnsupportedMedia,
  'deadline_exceeded' ||
  'internal_error' ||
  'network_error' ||
  'timeout' => l10n.tcTryAgain,
  _ => l10n.tcErrorCode(code),
};

/// One tool call in the timeline: approval, progress, result or error.
class LabeebToolCallCard extends StatelessWidget {
  const LabeebToolCallCard({
    required this.toolCallId,
    required this.controller,
    this.openExternal,
    this.compact = false,
    super.key,
  });

  final String toolCallId;
  final LabeebToolCallController controller;
  final NexaExternalOpener? openExternal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final a = controller.activity(toolCallId);
        if (a == null) return const SizedBox.shrink();
        final l10n = NexaLocalizations.of(context);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final colors = NexaColors.of(context);
        final c = a.call;
        final title = labeebToolTitle(l10n, c.tool);
        final purpose = c.arguments['purpose'];

        final (String status, Color color, Widget? lead) = switch (c.status) {
          NexaToolCallStatus.awaitingApproval => (
            a.phase == LabeebLocalPhase.approving
                ? l10n.tcRunning
                : c.tool == LabeebTools.themeApply
                ? l10n.tcThemePreview
                : l10n.tcWaitingForYou,
            colors.warning,
            null,
          ),
          NexaToolCallStatus.awaitingClient => (
            a.phase == LabeebLocalPhase.answering
                ? l10n.tcSending
                : l10n.tcRunning,
            colors.info,
            const _Spinner(),
          ),
          NexaToolCallStatus.running => (
            c.asynchronous && a.progress == null
                ? l10n.tcJobStarted
                : a.progress?.state == 'queued'
                ? l10n.tcJobQueued
                : l10n.tcRunning,
            colors.info,
            const _Spinner(),
          ),
          NexaToolCallStatus.succeeded => (l10n.tcDone, colors.success, null),
          NexaToolCallStatus.failed => (
            labeebErrorText(l10n, c.error?.code ?? 'internal_error'),
            scheme.error,
            null,
          ),
          NexaToolCallStatus.denied => (
            l10n.tcDenied,
            scheme.onSurfaceVariant,
            null,
          ),
          NexaToolCallStatus.expired => (
            l10n.tcExpired,
            scheme.onSurfaceVariant,
            null,
          ),
          NexaToolCallStatus.cancelled => (
            l10n.tcCancelled,
            scheme.onSurfaceVariant,
            null,
          ),
          NexaToolCallStatus.unknown => (
            l10n.tcRunning,
            scheme.onSurfaceVariant,
            null,
          ),
        };

        final waited = a.progress?.waitedSeconds;
        final children = <Widget>[
          Row(
            children: [
              Icon(_toolIcon(c.tool), color: scheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        if (lead != null) ...[lead, const SizedBox(width: 6)],
                        Flexible(
                          child: Text(
                            status,
                            key: Key('labeeb_tc_status_${c.id}'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (c.asynchronous && !c.status.terminal)
                TextButton(
                  key: Key('labeeb_tc_cancel_${c.id}'),
                  onPressed: () => controller.cancel(c.id),
                  child: Text(l10n.tcCancelJob),
                ),
            ],
          ),
          if (purpose is String && purpose.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.tcPurpose(purpose),
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (c.status == NexaToolCallStatus.running && waited != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tcJobWaited(waited),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          if (a.localError != null && c.status != NexaToolCallStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                labeebErrorText(l10n, a.localError!),
                key: Key('labeeb_tc_local_error_${c.id}'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          if (c.status == NexaToolCallStatus.awaitingApproval &&
              (a.phase == LabeebLocalPhase.awaitingUser ||
                  a.phase == LabeebLocalPhase.approving))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    key: Key('labeeb_tc_deny_${c.id}'),
                    onPressed: a.phase == LabeebLocalPhase.approving
                        ? null
                        : () => controller.decide(c.id, allow: false),
                    child: Text(l10n.tcNotNow),
                  ),
                  FilledButton(
                    key: Key('labeeb_tc_allow_${c.id}'),
                    onPressed: a.phase == LabeebLocalPhase.approving
                        ? null
                        : () => controller.decide(c.id, allow: true),
                    child: Text(
                      c.tool == LabeebTools.themeApply
                          ? l10n.tcApplyTheme
                          : l10n.tcAllow,
                    ),
                  ),
                ],
              ),
            ),
          if (c.status == NexaToolCallStatus.succeeded && c.result != null)
            LabeebResultList(
              tool: c.tool,
              result: c.result!,
              openExternal: openExternal,
            ),
          for (final asset in a.assets)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LabeebAssetView(
                asset: asset,
                bytes: controller.assetBytes,
                onDelete: controller.deleteAsset,
              ),
            ),
        ];
        return Material(
          key: Key('labeeb_tc_${c.id}'),
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 12,
    child: CircularProgressIndicator(strokeWidth: 1.6),
  );
}

/// Source-attributed results of search tools (web, news, sports, video,
/// places). Items show only what the gateway returned; attribution rules
/// of contract `sources` apply (news: "first seen", never "published";
/// `coverage: encyclopedia_only` labelled as reference articles).
class LabeebResultList extends StatelessWidget {
  const LabeebResultList({
    required this.tool,
    required this.result,
    this.openExternal,
    super.key,
  });

  final String tool;
  final Map<String, Object?> result;
  final NexaExternalOpener? openExternal;

  static const _listKeys = {
    LabeebTools.webSearch: 'results',
    LabeebTools.news: 'articles',
    LabeebTools.sports: 'matches',
    LabeebTools.video: 'videos',
    LabeebTools.placesNearby: 'places',
    LabeebTools.placesText: 'places',
  };

  @override
  Widget build(BuildContext context) {
    final key = _listKeys[tool];
    if (key == null) return const SizedBox.shrink();
    final items = [
      for (final i in (result[key] as List?) ?? const [])
        if (i is Map) i.cast<String, Object?>(),
    ];
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String? s(Map<String, Object?> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        key: Key('labeeb_results_$tool'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (result['coverage'] == 'encyclopedia_only')
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l10n.tcEncyclopedia,
                key: const Key('labeeb_results_encyclopedia'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final (i, m) in items.take(10).indexed)
            Builder(
              builder: (context) {
                final title = s(m, const ['title', 'name', 'headline']);
                final url = s(m, const ['url', 'link', 'google_maps_uri']);
                final https = url != null && isHttpsUrl(url) ? url : null;
                final source = s(m, const [
                  'publisher',
                  'source',
                  'channel',
                  'attribution',
                  'address',
                ]);
                final seen = s(m, const ['seen_at']);
                final sub = [
                  ?source,
                  if (seen != null) l10n.tcSeenAt(seen),
                  if (m['state'] == 'live') l10n.duiLive,
                ].join(' · ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Text(
                      '${m['rank'] ?? i + 1}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  title: Text(title ?? '—'),
                  subtitle: sub.isEmpty ? null : Text(sub),
                  trailing: https == null || openExternal == null
                      ? null
                      : IconButton(
                          tooltip: l10n.tcOpenLink,
                          icon: const Icon(Icons.open_in_new_rounded),
                          onPressed: () => openExternal!(Uri.parse(https)),
                        ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A server asset (owner-only bytes): images inline (tap for full screen),
/// files as a tile, a deleted file as a placeholder. Share and Delete are
/// in the menu; deletion is confirmed first ([onDelete] returns the
/// gateway error code, null when deleted).
class LabeebAssetView extends StatefulWidget {
  const LabeebAssetView({
    required this.asset,
    required this.bytes,
    this.onDelete,
    this.share,
    this.playback,
    super.key,
  });

  final NexaAssetRef asset;

  /// Audio player for audio assets; the plugin's by default.
  final NexaAudioPlayback Function()? playback;
  final Future<Uint8List> Function(String assetId) bytes;
  final Future<String?> Function(String assetId)? onDelete;

  /// The share sheet; the plugin's by default.
  final NexaShareSheet? share;

  @override
  State<LabeebAssetView> createState() => _LabeebAssetViewState();
}

class _LabeebAssetViewState extends State<LabeebAssetView> {
  late final Future<Uint8List>? _data = widget.asset.isImage
      ? widget.bytes(widget.asset.id)
      : null;
  bool _busy = false;

  NexaAssetRef get _asset => widget.asset;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await widget.bytes(_asset.id);
      final ext = switch (_asset.mime) {
        'image/png' => '.png',
        'image/jpeg' => '.jpg',
        'image/webp' => '.webp',
        'application/pdf' => '.pdf',
        'text/plain' => '.txt',
        'audio/wav' || 'audio/x-wav' => '.wav',
        'audio/mpeg' => '.mp3',
        _ => '',
      };
      final f = File(
        '${Directory.systemTemp.path}/'
        '${_asset.filename ?? 'labeeb_${_asset.id}$ext'}',
      );
      await f.writeAsBytes(bytes, flush: true);
      await (widget.share ?? const PluginShareSheet()).share(
        filePaths: [f.path],
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(NexaLocalizations.of(context).tcTryAgain)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = NexaLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.tcDeleteAssetTitle),
        content: Text(l10n.tcDeleteAssetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('labeeb_asset_delete_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final code = await widget.onDelete!(_asset.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (code != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.tcDeleteFailed)));
    }
  }

  void _openFull(Uint8List bytes) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(
                _asset.generated
                    ? NexaLocalizations.of(context).tcGenerated
                    : _asset.filename ?? '',
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(NexaLocalizations l10n) => _busy
      ? const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      : PopupMenuButton<String>(
          key: Key('labeeb_asset_menu_${_asset.id}'),
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) => unawaited(v == 'share' ? _share() : _delete()),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'share',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.ios_share_rounded),
                title: Text(l10n.tcShare),
              ),
            ),
            if (widget.onDelete != null)
              PopupMenuItem(
                key: Key('labeeb_asset_delete_${_asset.id}'),
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(l10n.deleteAction),
                ),
              ),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_asset.deleted) {
      return ListTile(
        key: Key('labeeb_asset_deleted_${_asset.id}'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.hide_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
        title: Text(
          l10n.tcAssetDeleted,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    if (_asset.isAudio) {
      return LabeebAudioAssetTile(
        asset: _asset,
        bytes: widget.bytes,
        playback: widget.playback,
        trailing: _menu(l10n),
      );
    }
    if (_data == null) {
      return ListTile(
        key: Key('labeeb_asset_${_asset.id}'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.description_outlined),
        title: Text(_asset.filename ?? _asset.mime ?? 'file'),
        trailing: _menu(l10n),
      );
    }
    return Semantics(
      image: true,
      label: _asset.generated ? l10n.tcGenerated : null,
      child: ClipRRect(
        key: Key('labeeb_asset_${_asset.id}'),
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<Uint8List>(
          future: _data,
          builder: (context, snap) => snap.hasData
              ? Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _openFull(snap.data!),
                      child: Image.memory(
                        snap.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 160,
                          color: scheme.surfaceContainerHigh,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    if (_asset.generated)
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              l10n.tcGenerated,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      top: 4,
                      end: 4,
                      child: Material(
                        color: scheme.surface.withValues(alpha: 0.85),
                        shape: const CircleBorder(),
                        child: _menu(l10n),
                      ),
                    ),
                  ],
                )
              : Container(
                  height: 160,
                  color: scheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: snap.hasError
                      ? Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurfaceVariant,
                        )
                      : const CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      ),
    );
  }
}
