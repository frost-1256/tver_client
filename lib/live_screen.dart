import 'package:flutter/material.dart';

import 'epg_screen.dart';
import 'models.dart';
import 'player_screen.dart';
import 'tver_api.dart';

/// Simulcast channel list （リアルタイム放送）.
class LiveScreen extends StatefulWidget {
  final TverApi api;
  const LiveScreen({super.key, required this.api});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _ChannelWithProgram {
  final LiveChannel channel;
  final LiveProgram? current;
  final LiveProgram? next;
  const _ChannelWithProgram(this.channel, this.current, this.next);
}

class _LiveScreenState extends State<LiveScreen> {
  late Future<List<_ChannelWithProgram>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_ChannelWithProgram>> _load() async {
    final channels = await widget.api.liveChannels();
    if (channels.isEmpty) {
      throw const TverException('ライブチャンネルを取得できませんでした');
    }
    final now = DateTime.now();
    return Future.wait(
      channels.map((ch) async {
        LiveProgram? current;
        LiveProgram? next;
        try {
          final timeline = await widget.api.liveTimeline(ch.id);
          for (final p in timeline) {
            if (p.isCurrentAt(now)) {
              current = p;
            } else if (current != null && next == null && p.startAt >= current.endAt) {
              next = p;
              break;
            }
          }
        } catch (_) {
          // Timeline is best-effort decoration.
        }
        return _ChannelWithProgram(ch, current, next);
      }),
    );
  }

  void _openChannel(_ChannelWithProgram item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          api: widget.api,
          liveChannel: item.channel,
          liveCurrent: item.current,
          knownTitle: item.current?.title,
          knownSeriesTitle: item.channel.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('リアルタイム放送'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EpgScreen(api: widget.api)),
            ),
            icon: const Icon(Icons.event_note),
            tooltip: '番組表',
          ),
          IconButton(
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      body: FutureBuilder<List<_ChannelWithProgram>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() => _future = _load()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('再試行'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final cur = item.current;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.tv,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          item.channel.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('LIVE'),
                          avatar: const Icon(Icons.sensors, size: 16),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    subtitle: cur == null
                        ? const Text('放送中の番組情報なし')
                        : Text(
                            '${cur.timeRangeLabel} ${cur.title}'
                            '${item.next != null ? '\n次: ${item.next!.timeRangeLabel} ${item.next!.title}' : ''}',
                          ),
                    trailing: const Icon(Icons.play_circle_outline),
                    onTap: () => _openChannel(item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
