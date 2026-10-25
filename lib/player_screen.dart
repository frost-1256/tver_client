import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'models.dart';
import 'pip.dart';
import 'tver_api.dart';

class PlayerScreen extends StatefulWidget {
  final TverApi api;
  final String? episodeId;
  final String? liveEpisodeId;
  final LiveChannel? liveChannel;
  final LiveProgram? liveCurrent;
  final String? knownTitle;
  final String? knownSeriesTitle;

  const PlayerScreen({
    super.key,
    required this.api,
    this.episodeId,
    this.liveEpisodeId,
    this.liveChannel,
    this.liveCurrent,
    this.knownTitle,
    this.knownSeriesTitle,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<bool>? _pipSub;
  PlayInfo? _info;
  String? _error;
  bool _loading = true;
  bool _inPip = false;

  bool get _isChannelLive => widget.liveChannel != null;
  bool get _isLiveEpisode => widget.liveEpisodeId != null;
  // Seeking makes sense for VOD episodes and DVR-backed live episodes,
  // not for the live edge of a simulcast channel.
  bool get _canSeek => !_isChannelLive;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    // Leaving the app mid-playback shrinks into PiP (Android).
    Pip.setAutoEnter(true);
    _pipSub = Pip.modeChanges.listen((inPip) {
      if (mounted) setState(() => _inPip = inPip);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final info = _isChannelLive
          ? await widget.api.resolveLive(
              widget.liveChannel!,
              current: widget.liveCurrent,
            )
          : _isLiveEpisode
          ? await widget.api.resolveLiveEpisode(widget.liveEpisodeId!)
          : await widget.api.resolveEpisode(widget.episodeId!);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
      await _player.open(Media(info.streamUrl));
      if (info.subtitleUrl != null) {
        try {
          await _player.setSubtitleTrack(
            SubtitleTrack.uri(info.subtitleUrl!),
          );
        } catch (_) {
          // Subtitles are best-effort.
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _seekBy(Duration delta) async {
    final target = _player.state.position + delta;
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  void dispose() {
    _pipSub?.cancel();
    Pip.setAutoEnter(false);
    _player.dispose();
    super.dispose();
  }

  Widget _videoArea({required bool pipMode}) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Video(
          controller: _controller,
          controls: pipMode ? NoVideoControls : AdaptiveVideoControls,
        ),
        if (_loading) const CircularProgressIndicator(color: Colors.white),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // In PiP the window shows the video only — no app bar, no texts.
    if (_inPip) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _videoArea(pipMode: true),
      );
    }
    final theme = Theme.of(context);
    final title =
        _info?.seriesTitle ?? widget.knownSeriesTitle ?? _info?.title ?? 'TVer';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          if (Pip.supported)
            IconButton(
              onPressed: () => Pip.enter(),
              icon: const Icon(Icons.picture_in_picture_alt),
              tooltip: 'ピクチャインピクチャ',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _videoArea(pipMode: false),
            ),
          ),
          if (_canSeek)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () => _seekBy(const Duration(seconds: -10)),
                    icon: const Icon(Icons.replay_10),
                    iconSize: 32,
                    tooltip: '10秒戻る',
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () => _seekBy(const Duration(seconds: 10)),
                    icon: const Icon(Icons.forward_10),
                    iconSize: 32,
                    tooltip: '10秒進む',
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _info?.title ?? widget.knownTitle ?? '',
                    style: theme.textTheme.titleLarge,
                  ),
                  if (_info?.isLive == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: const Text('ライブ'),
                        avatar: const Icon(Icons.sensors, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_info?.description != null)
                    Text(
                      _info!.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
