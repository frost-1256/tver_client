import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'series_screen.dart';
import 'tver_api.dart';

/// Shared tap routing for any content item (episode / series / live).
void openContentItem(BuildContext context, TverApi api, ContentItem item) {
  if (item.type == 'series') {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SeriesScreen(api: api, seriesId: item.id, knownTitle: item.title),
      ),
    );
  } else if (item.type == 'live') {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          api: api,
          liveEpisodeId: item.id,
          knownTitle: item.title,
          knownSeriesTitle: item.seriesTitle,
        ),
      ),
    );
  } else if (item.type == 'episode') {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          api: api,
          episodeId: item.id,
          knownTitle: item.title,
          knownSeriesTitle: item.seriesTitle,
        ),
      ),
    );
  } else if (item.seriesID != null) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeriesScreen(api: api, seriesId: item.seriesID!),
      ),
    );
  }
}

/// A 16:9 thumbnail card used in the home rails.
class ContentCard extends StatelessWidget {
  final ContentItem item;
  final VoidCallback onTap;

  const ContentCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = item.type == 'series' ? 220.0 : 248.0;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        item.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.tv,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (item.rank != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          '${item.rank}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (item.durationLabel != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.durationLabel!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.type == 'episode' && item.seriesTitle != null
                    ? item.seriesTitle!
                    : item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                item.type == 'episode'
                    ? item.title
                    : (item.broadcasterName ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (item.remainingLabel != null)
                Text(
                  item.remainingLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One titled horizontal rail on the home screen.
class ContentRailView extends StatelessWidget {
  final ContentRail rail;
  final void Function(ContentItem item) onItemTap;

  const ContentRailView({
    super.key,
    required this.rail,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            rail.itemType == 'episode'
                ? '${rail.title}のエピソード'
                : rail.itemType == 'series'
                ? '${rail.title}のシリーズ'
                : rail.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 208,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: rail.items.length,
            itemBuilder: (context, i) {
              final item = rail.items[i];
              return ContentCard(item: item, onTap: () => onItemTap(item));
            },
          ),
        ),
      ],
    );
  }
}
