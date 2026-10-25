import 'package:flutter/material.dart';

import 'models.dart';
import 'tver_api.dart';
import 'widgets.dart';

/// Browse hub: category shortcuts + special features.
class BrowseScreen extends StatefulWidget {
  final TverApi api;
  const BrowseScreen({super.key, required this.api});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late Future<List<ContentItem>> _specialsFuture;

  @override
  void initState() {
    super.initState();
    _specialsFuture = widget.api.specials();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('さがす')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'カテゴリ',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (id, name) in TverApi.categoryTabs)
                  ActionChip(
                    avatar: const Icon(Icons.category, size: 18),
                    label: Text(name),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoryScreen(
                          api: widget.api,
                          tabId: id,
                          tabName: name,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              '特集',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FutureBuilder<List<ContentItem>>(
            future: _specialsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('特集を取得できませんでした: ${snapshot.error}'),
                );
              }
              final specials = snapshot.data!;
              return Column(
                children: [
                  for (final sp in specials)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              sp.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.auto_awesome),
                            ),
                          ),
                        ),
                        title: Text(sp.title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SpecialScreen(
                              api: widget.api,
                              mainId: sp.id,
                              title: sp.title,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One category page as rails (callCategoryHome).
class CategoryScreen extends StatelessWidget {
  final TverApi api;
  final String tabId;
  final String tabName;
  const CategoryScreen({
    super.key,
    required this.api,
    required this.tabId,
    required this.tabName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tabName)),
      body: FutureBuilder<List<ContentRail>>(
        future: api.categoryHome(tabId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final rails = snapshot.data!;
          return ListView.builder(
            itemCount: rails.length,
            itemBuilder: (context, i) => ContentRailView(
              rail: rails[i],
              onItemTap: (item) => openContentItem(context, api, item),
            ),
          );
        },
      ),
    );
  }
}

/// A special feature: sub-sections, then their playable items.
class SpecialScreen extends StatelessWidget {
  final TverApi api;
  final String mainId;
  final String title;
  const SpecialScreen({
    super.key,
    required this.api,
    required this.mainId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<List<ContentItem>>(
        future: api.specialSubs(mainId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final subs = snapshot.data!;
          if (subs.isEmpty) {
            return const Center(child: Text('コンテンツがありません'));
          }
          // A single sub-section opens directly.
          if (subs.length == 1) {
            return _SpecialItems(api: api, subId: subs.first.id);
          }
          return ListView.builder(
            itemCount: subs.length,
            itemBuilder: (context, i) {
              final sub = subs[i];
              return ListTile(
                title: Text(sub.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(sub.title)),
                      body: _SpecialItems(api: api, subId: sub.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SpecialItems extends StatelessWidget {
  final TverApi api;
  final String subId;
  const _SpecialItems({required this.api, required this.subId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContentItem>>(
      future: api.specialItems(subId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('コンテンツがありません'));
        }
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 264,
            mainAxisExtent: 216,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return ContentCard(
              item: item,
              onTap: () => openContentItem(context, api, item),
            );
          },
        );
      },
    );
  }
}
