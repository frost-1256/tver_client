import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'browse_screen.dart';
import 'live_screen.dart';
import 'models.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'series_screen.dart';
import 'tver_api.dart';
import 'widgets.dart';

const _seedColor = Color(0xFF0B57D0);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const TverApp());
}

class TverApp extends StatelessWidget {
  const TverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.light,
            );
        final darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.dark,
            );
        return MaterialApp(
          title: 'TVer Client',
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = TverApi();
  late Future<List<ContentRail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRails();
  }

  Future<List<ContentRail>> _loadRails() async {
    final rails = <ContentRail>[];
    try {
      rails.addAll(await _api.episodeRankings());
    } catch (_) {}
    try {
      rails.addAll(await _api.seriesRankings());
    } catch (_) {}
    if (rails.isEmpty) {
      throw const TverException('コンテンツを取得できませんでした');
    }
    return rails;
  }

  void _openItem(ContentItem item) {
    if (item.type == 'series') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              SeriesScreen(api: _api, seriesId: item.id, knownTitle: item.title),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            api: _api,
            episodeId: item.id,
            knownTitle: item.title,
            knownSeriesTitle: item.seriesTitle,
          ),
        ),
      );
    }
  }

  Future<void> _openUrlDialog() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('URL / IDで開く'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://tver.jp/episodes/xxxx または ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('開く'),
          ),
        ],
      ),
    );
    if (input == null || input.isEmpty || !mounted) return;
    final match = RegExp(r'(episodes?|series)/(\w+)').firstMatch(input);
    String? episodeId;
    String? seriesId;
    if (match != null) {
      if (match.group(1)!.startsWith('series')) {
        seriesId = match.group(2);
      } else {
        episodeId = match.group(2);
      }
    } else if (input.startsWith('ep')) {
      episodeId = input;
    } else if (input.startsWith('sr')) {
      seriesId = input;
    }
    if (episodeId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(api: _api, episodeId: episodeId!),
        ),
      );
    } else if (seriesId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeriesScreen(api: _api, seriesId: seriesId!),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL / IDを認識できませんでした')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TVer'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BrowseScreen(api: _api)),
            ),
            icon: const Icon(Icons.explore),
            tooltip: 'さがす',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LiveScreen(api: _api)),
            ),
            icon: const Icon(Icons.sensors),
            tooltip: 'リアルタイム放送',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SearchScreen(api: _api)),
            ),
            icon: const Icon(Icons.search),
            tooltip: '検索',
          ),
          IconButton(
            onPressed: _openUrlDialog,
            icon: const Icon(Icons.link),
            tooltip: 'URL / IDで開く',
          ),
          IconButton(
            onPressed: () => setState(() => _future = _loadRails()),
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      body: FutureBuilder<List<ContentRail>>(
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
                      onPressed: () => setState(() => _future = _loadRails()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('再試行'),
                    ),
                  ],
                ),
              ),
            );
          }
          final rails = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _loadRails());
              await _future;
            },
            child: ListView.builder(
              itemCount: rails.length,
              itemBuilder: (context, i) =>
                  ContentRailView(rail: rails[i], onItemTap: _openItem),
            ),
          );
        },
      ),
    );
  }
}
