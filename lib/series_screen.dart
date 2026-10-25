import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'tver_api.dart';

class SeriesScreen extends StatefulWidget {
  final TverApi api;
  final String seriesId;
  final String? knownTitle;

  const SeriesScreen({
    super.key,
    required this.api,
    required this.seriesId,
    this.knownTitle,
  });

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  late Future<_SeriesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SeriesData> _load() async {
    final title = await widget.api.seriesTitle(widget.seriesId);
    final seasons = await widget.api.seriesSeasons(widget.seriesId);
    final episodesBySeason = <ContentItem, List<ContentItem>>{};
    for (final season in seasons) {
      episodesBySeason[season] = await widget.api.seasonEpisodes(season.id);
    }
    return _SeriesData(title: title, episodesBySeason: episodesBySeason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.knownTitle ?? 'シリーズ',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<_SeriesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final data = snapshot.data!;
          if (data.episodesBySeason.isEmpty) {
            return const Center(child: Text('エピソードが見つかりませんでした'));
          }
          return ListView(
            children: [
              for (final entry in data.episodesBySeason.entries) ...[
                if (data.episodesBySeason.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Text(
                      entry.key.title.isEmpty ? 'エピソード' : entry.key.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                for (final ep in entry.value)
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          ep.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.tv),
                          ),
                        ),
                      ),
                    ),
                    title: Text(ep.title, maxLines: 2),
                    subtitle: Text(
                      [
                        if (ep.broadcastDateLabel != null)
                          ep.broadcastDateLabel!,
                        if (ep.durationLabel != null) ep.durationLabel!,
                        if (ep.remainingLabel != null) ep.remainingLabel!,
                      ].join(' ・ '),
                    ),
                    trailing: const Icon(Icons.play_circle_outline),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            api: widget.api,
                            episodeId: ep.id,
                            knownTitle: ep.title,
                            knownSeriesTitle: data.title,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SeriesData {
  final String title;
  final Map<ContentItem, List<ContentItem>> episodesBySeason;
  const _SeriesData({required this.title, required this.episodesBySeason});
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}
