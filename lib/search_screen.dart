import 'package:flutter/material.dart';

import 'models.dart';
import 'tver_api.dart';
import 'widgets.dart';

/// Keyword search against the same endpoint the official web app uses.
class SearchScreen extends StatefulWidget {
  final TverApi api;

  const SearchScreen({super.key, required this.api});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Future<List<ContentItem>>? _future;
  String _keyword = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final kw = _controller.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _keyword = kw;
      _future = widget.api.search(kw);
    });
  }

  void _openItem(ContentItem item) => openContentItem(context, widget.api, item);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: '番組名・出演者などで検索',
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _controller.clear();
                      _future = null;
                      _keyword = '';
                    }),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          IconButton(
            onPressed: _submit,
            icon: const Icon(Icons.search),
            tooltip: '検索',
          ),
        ],
      ),
      body: _future == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'キーワードを入力して検索',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : FutureBuilder<List<ContentItem>>(
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
                            onPressed: _submit,
                            icon: const Icon(Icons.refresh),
                            label: const Text('再試行'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      '「$_keyword」は見つかりませんでした',
                      style: theme.textTheme.bodyLarge,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        '「$_keyword」の検索結果 ${items.length}件',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
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
                            onTap: () => _openItem(item),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
