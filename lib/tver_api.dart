import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Minimal client for the (undocumented) TVer web platform API.
///
/// Flow verified against the live service:
///  1. POST platform-api.tver.jp/v2/api/platform_users/browser/create
///     -> platform_uid / platform_token (guest session)
///  2. platform-api.tver.jp/service/api/v1/callXxx with that session
///  3. Episode playback: statics.tver.jp/content/episode/<id>.json gives a
///     "streaks" reference; the HLS URL comes from playback.api.streaks.jp
///     using a monthly-rotating API key published at
///     player.tver.jp/player/streaks_info_v2.json.
///  4. Live (simulcast): service-api.tver.jp/api/v1/callLiveChannel lists
///     the channels together with their Streaks project/media ids, which
///     resolve through the exact same Streaks playback call.
class TverApi {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  static const _platformHeaders = {
    'x-tver-platform-type': 'web',
    'Origin': 'https://tver.jp',
    'Referer': 'https://tver.jp/',
    'User-Agent': _ua,
  };

  String? _uid;
  String? _token;
  Map<String, dynamic>? _streaksInfo;

  Future<void> _ensureSession() async {
    if (_uid != null && _token != null) return;
    final res = await http.post(
      Uri.parse(
        'https://platform-api.tver.jp/v2/api/platform_users/browser/create',
      ),
      headers: {'User-Agent': _ua},
      body: {'device_type': 'pc'},
    );
    if (res.statusCode != 200) {
      throw TverException('セッションの作成に失敗しました (HTTP ${res.statusCode})');
    }
    final result = (jsonDecode(res.body) as Map)['result'] as Map;
    _uid = result['platform_uid']?.toString();
    _token = result['platform_token']?.toString();
    if (_uid == null || _token == null) {
      throw const TverException('セッションの作成に失敗しました');
    }
  }

  Map<String, String> get _query => {
    'platform_uid': _uid!,
    'platform_token': _token!,
  };

  Future<Map<String, dynamic>> _getJson(
    String url, {
    Map<String, String>? headers,
    Map<String, String>? query,
  }) async {
    await _ensureSession();
    final uri = Uri.parse(url).replace(
      queryParameters: {..._query, ...?query},
    );
    final res = await http.get(uri, headers: headers ?? _platformHeaders);
    if (res.statusCode != 200) {
      throw TverException('APIエラー (HTTP ${res.statusCode}): $url');
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _getJsonNoSession(
    String url, {
    Map<String, String>? headers,
  }) async {
    final res = await http.get(
      Uri.parse(url),
      headers: headers ?? {'User-Agent': _ua},
    );
    if (res.statusCode != 200) {
      throw TverException('APIエラー (HTTP ${res.statusCode}): $url');
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  List<ContentItem> _itemsOf(Map<String, dynamic> json) {
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final contents = (result['contents'] as List?) ?? const [];
    return contents
        .whereType<Map>()
        .map((e) => ContentItem.fromEntry(e.cast<String, dynamic>()))
        .where((i) => i.id.isNotEmpty)
        .toList();
  }

  List<ContentRail> _railsOf(Map<String, dynamic> json, String itemType) {
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final groups = (result['contents'] as List?) ?? const [];
    final rails = <ContentRail>[];
    for (final g in groups.whereType<Map>()) {
      final group = g.cast<String, dynamic>();
      final title =
          ((group['content'] as Map?)?['title'])?.toString() ?? 'ランキング';
      final nested = (group['contents'] as List?) ?? const [];
      final items = nested
          .whereType<Map>()
          .map((e) => ContentItem.fromEntry(e.cast<String, dynamic>()))
          .where((i) => i.id.isNotEmpty)
          .toList();
      if (items.isNotEmpty) {
        rails.add(ContentRail(title: title, itemType: itemType, items: items));
      }
    }
    return rails;
  }

  /// Keyword search — the same endpoint the official web app uses
  /// (appsdk.js: TVerApp.callKeywordSearchV2). Params are merged with the
  /// guest session by [_getJson]; `require_data: later` is what the SDK
  /// sends and routes the call to the platform API host.
  Future<List<ContentItem>> search(String keyword) async {
    final json = await _getJson(
      'https://platform-api.tver.jp/service/api/v2/callKeywordSearch',
      query: {'keyword': keyword, 'require_data': 'later'},
    );
    final code = (json['code'] as num?)?.toInt() ?? 0;
    if (code != 0) {
      throw TverException('検索に失敗しました (code $code)');
    }
    return _itemsOf(json);
  }

  /// Home rail #1: episode rankings (総合 + genres).
  Future<List<ContentRail>> episodeRankings() async {
    final json = await _getJson(
      'https://platform-api.tver.jp/service/api/v1/callEpisodeRanking',
    );
    return _railsOf(json, 'episode');
  }

  /// Home rail #2: series rankings.
  Future<List<ContentRail>> seriesRankings() async {
    final json = await _getJson(
      'https://platform-api.tver.jp/service/api/v1/callRanking',
    );
    return _railsOf(json, 'series');
  }

  Future<String> seriesTitle(String seriesId) async {
    final json = await _getJson(
      'https://platform-api.tver.jp/service/api/v2/callSeries/$seriesId',
    );
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final content =
        (result['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final inner =
        (content['content'] as Map?)?.cast<String, dynamic>() ?? {};
    return inner['title']?.toString() ?? 'シリーズ';
  }

  Future<List<ContentItem>> seriesSeasons(String seriesId) async {
    final json = await _getJsonNoSession(
      'https://service-api.tver.jp/api/v1/callSeriesSeasons/$seriesId',
      headers: _platformHeaders,
    );
    return _itemsOf(json)
        .where((i) => i.type == 'season')
        .toList(growable: false);
  }

  Future<List<ContentItem>> seasonEpisodes(String seasonId) async {
    final json = await _getJson(
      'https://platform-api.tver.jp/service/api/v1/callSeasonEpisodes/$seasonId',
    );
    return _itemsOf(json)
        .where((i) => i.type == 'episode')
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Live (simulcast)
  // ---------------------------------------------------------------------------

  /// The simulcast channels (日テレ / テレ朝 / TBS / テレ東 / フジ).
  Future<List<LiveChannel>> liveChannels() async {
    final json = await _getJson(
      'https://service-api.tver.jp/api/v1/callLiveChannel',
    );
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final contents = (result['contents'] as List?) ?? const [];
    return contents
        .whereType<Map>()
        .map((e) => LiveChannel.fromEntry(e.cast<String, dynamic>()))
        .where((c) => c.id.isNotEmpty && c.projectId.isNotEmpty)
        .toList();
  }

  /// Program timeline of one live channel (best-effort).
  Future<List<LiveProgram>> liveTimeline(String channelId) async {
    final json = await _getJson(
      'https://service-api.tver.jp/api/v1/callLiveTimeline/$channelId',
    );
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final contents = (result['contents'] as List?) ?? const [];
    return contents
        .whereType<Map>()
        .map((e) => LiveProgram.fromEntry(e.cast<String, dynamic>()))
        .where((p) => p.liveEpisodeId.isNotEmpty)
        .toList();
  }

  /// Resolves a simulcast channel to its live HLS stream.
  Future<PlayInfo> resolveLive(LiveChannel channel, {LiveProgram? current}) async {
    final pb = await _streaksPlayback(channel.projectId, channel.mediaId);
    return PlayInfo(
      episodeId: channel.id,
      streamUrl: pb.streamUrl,
      title: current?.title ?? '${channel.name} リアルタイム放送',
      seriesTitle: channel.name,
      description: current != null
          ? '${current.timeRangeLabel} ${current.title}'
          : null,
      subtitleUrl: pb.subtitleUrl,
      isLive: true,
    );
  }

  /// Resolves a live episode (le... id: special live events, program-linked
  /// streams, search results of type "live") to a playable stream.
  /// During the broadcast window this is the channel's simulcast stream;
  /// afterwards the DVR recording is used while its window is open.
  Future<PlayInfo> resolveLiveEpisode(String liveId) async {
    await _ensureSession();
    var version = '6';
    String? metaTitle;
    String? metaSeriesTitle;
    try {
      final j = await _getJson(
        'https://platform-api.tver.jp/service/api/v1/callLiveEpisode/$liveId',
        query: {'require_data': 'mylist'},
      );
      final result = (j['result'] as Map?)?.cast<String, dynamic>() ?? {};
      final episode = (result['episode'] as Map?)?.cast<String, dynamic>();
      final content =
          (episode?['content'] as Map?)?.cast<String, dynamic>() ?? {};
      version = content['version']?.toString() ?? version;
      metaTitle = content['title']?.toString();
      metaSeriesTitle = content['seriesTitle']?.toString();
    } catch (_) {
      // Metadata is best-effort.
    }
    final statics = await _getJsonNoSession(
      'https://statics.tver.jp/content/live/$liveId.json?v=$version',
      headers: {'Referer': 'https://tver.jp/', 'User-Agent': _ua},
    );
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final view = (statics['viewStatus'] as Map?)?.cast<String, dynamic>();
    final dvr = (statics['dvr'] as Map?)?.cast<String, dynamic>();
    Map<String, dynamic>? pick;
    if (view != null &&
        nowSec >= ((view['startAt'] as num?)?.toInt() ?? 0) &&
        nowSec < ((view['endAt'] as num?)?.toInt() ?? 0)) {
      pick = (statics['liveVideo'] as Map?)?.cast<String, dynamic>();
    }
    if (pick == null &&
        dvr != null &&
        dvr['allow'] == true &&
        nowSec >= ((dvr['startAt'] as num?)?.toInt() ?? 0) &&
        nowSec <= ((dvr['endAt'] as num?)?.toInt() ?? 0)) {
      pick = (statics['dvrVideo'] as Map?)?.cast<String, dynamic>();
    }
    if (pick == null) {
      if (view != null &&
          nowSec < ((view['startAt'] as num?)?.toInt() ?? 0)) {
        throw const TverException('まだ放送が始まっていません');
      }
      throw const TverException('このライブは配信期間が終了しています');
    }
    final projectId = pick['projectID']?.toString();
    final mediaId = pick['mediaID']?.toString();
    if (projectId == null || mediaId == null || mediaId.isEmpty) {
      throw const TverException('再生情報が見つかりませんでした');
    }
    final pb = await _streaksPlayback(projectId, mediaId);
    return PlayInfo(
      episodeId: liveId,
      streamUrl: pb.streamUrl,
      title: statics['title']?.toString() ?? metaTitle ?? 'ライブ',
      seriesTitle: metaSeriesTitle,
      description: statics['description']?.toString(),
      subtitleUrl: pb.subtitleUrl,
      isLive: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Categories / specials / program guide
  // ---------------------------------------------------------------------------

  /// Category tabs as served by callCategoryHome (verified 2026-10-25).
  static const categoryTabs = <(String, String)>[
    ('drama', 'ドラマ'),
    ('variety', 'バラエティ'),
    ('anime', 'アニメ'),
    ('news', 'ニュース'),
    ('sports', 'スポーツ'),
  ];

  /// One category page (callCategoryHome/{tabId}) as content rails.
  Future<List<ContentRail>> categoryHome(String tabId) async {
    final json = await _getJson(
      'https://platform-api.tver.jp/service/api/v1/callCategoryHome/$tabId',
      query: {'require_data': 'mylist,resume,later'},
    );
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final components = (result['components'] as List?) ?? const [];
    final rails = <ContentRail>[];
    for (final c in components.whereType<Map>()) {
      final comp = c.cast<String, dynamic>();
      if (comp['type'] == 'banner') continue;
      final nested = (comp['contents'] as List?) ?? const [];
      final items = nested
          .whereType<Map>()
          .map((e) => ContentItem.fromEntry(e.cast<String, dynamic>()))
          .where(
            (i) =>
                i.id.isNotEmpty &&
                (i.type == 'episode' || i.type == 'series' || i.type == 'live'),
          )
          .toList();
      if (items.isEmpty) continue;
      final label = comp['label']?.toString();
      final title = (label != null && label.isNotEmpty)
          ? label
          : (comp['type'] == 'episodeRanking' ? 'ランキング' : 'ピックアップ');
      rails.add(ContentRail(title: title, itemType: 'mixed', items: items));
    }
    if (rails.isEmpty) {
      throw const TverException('カテゴリを取得できませんでした');
    }
    return rails;
  }

  /// Special features list (callSpecial, type specialMain entries).
  Future<List<ContentItem>> specials() async {
    final json = await _getJson(
      'https://service-api.tver.jp/api/v1/callSpecial',
    );
    return _itemsOf(json)
        .where((i) => i.type == 'specialMain')
        .toList(growable: false);
  }

  /// Sub-sections of one special (callSpecialContents/{mainId}).
  Future<List<ContentItem>> specialSubs(String mainId) async {
    final json = await _getJson(
      'https://platform-api.tver.jp/service/api/v1/callSpecialContents/$mainId',
      query: {'require_data': 'mylist[special][$mainId]'},
    );
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final subs = (result['specialContents'] as List?) ?? const [];
    return subs
        .whereType<Map>()
        .map((e) => ContentItem.fromEntry(e.cast<String, dynamic>()))
        .where((i) => i.id.isNotEmpty)
        .toList();
  }

  /// Playable items of one special sub-section
  /// (callSpecialContentsDetail/{subId} -> result.contents.content.contents).
  Future<List<ContentItem>> specialItems(String subId) async {
    final json = await _getJson(
      'https://platform-api.tver.jp/service/api/v1/callSpecialContentsDetail/$subId',
      query: {'require_data': 'mylist,later'},
    );
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final contents = (result['contents'] as Map?)?.cast<String, dynamic>() ?? {};
    final content = (contents['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = (content['contents'] as List?) ?? const [];
    return items
        .whereType<Map>()
        .map((e) => ContentItem.fromEntry(e.cast<String, dynamic>()))
        .where((i) => i.id.isNotEmpty)
        .toList();
  }

  /// Terrestrial program guide for one day (callEPGv2, type=live).
  Future<List<EpgChannel>> epg(DateTime date) async {
    final ymd =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final json = await _getJson(
      'https://service-api.tver.jp/api/v1/callEPGv2',
      query: {'date': ymd, 'type': 'live'},
    );
    final result = (json['result'] as Map?)?.cast<String, dynamic>() ?? {};
    final contents = (result['contents'] as List?) ?? const [];
    final channels = <EpgChannel>[];
    for (final c in contents.whereType<Map>()) {
      final ch = c.cast<String, dynamic>();
      final broadcaster =
          (ch['broadcaster'] as Map?)?.cast<String, dynamic>() ?? {};
      final programs = ((ch['programs'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => EpgProgram.fromJson(p.cast<String, dynamic>()))
          .toList();
      channels.add(
        EpgChannel(
          broadcasterId: broadcaster['id']?.toString() ?? '',
          name: broadcaster['name']?.toString() ?? '',
          programs: programs,
        ),
      );
    }
    if (channels.isEmpty) {
      throw const TverException('番組表を取得できませんでした');
    }
    return channels;
  }

  // ---------------------------------------------------------------------------
  // Streaks playback (shared by episodes and live)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _streaksInfoJson() async {
    if (_streaksInfo != null) return _streaksInfo!;
    final res = await http.get(
      Uri.parse('https://player.tver.jp/player/streaks_info_v2.json'),
      headers: {'User-Agent': _ua},
    );
    if (res.statusCode != 200) {
      throw TverException('プレイヤー情報の取得に失敗しました (HTTP ${res.statusCode})');
    }
    _streaksInfo = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    return _streaksInfo!;
  }

  /// Picks this month's API key for a Streaks project.
  /// Keys rotate monthly: key0{month % 6, or 6} in JST (same scheme as yt-dlp).
  Future<String> _monthlyApiKey(String projectId) async {
    final info = await _streaksInfoJson();
    final project = (info[projectId] as Map?)?.cast<String, dynamic>();
    final apiKeys = (project?['api_key'] as Map?)?.cast<String, dynamic>();
    if (apiKeys == null) {
      throw const TverException('再生キーが見つかりませんでした');
    }
    final monthJst = DateTime.now().toUtc().add(const Duration(hours: 9)).month;
    var idx = monthJst % 6;
    if (idx == 0) idx = 6;
    final apiKey = apiKeys['key0$idx']?.toString();
    if (apiKey == null) {
      throw const TverException('再生キーが見つかりませんでした');
    }
    return apiKey;
  }

  Future<({String streamUrl, String? subtitleUrl, String? type})>
  _streaksPlayback(String projectId, String mediaId) async {
    final apiKey = await _monthlyApiKey(projectId);
    final res = await http.get(
      Uri.parse(
        'https://playback.api.streaks.jp/v1/projects/$projectId/medias/$mediaId',
      ),
      headers: {
        'X-Streaks-Api-Key': apiKey,
        'Origin': 'https://tver.jp',
        'Referer': 'https://tver.jp/',
        'Accept': 'application/json',
        'User-Agent': _ua,
      },
    );
    if (res.statusCode == 403) {
      throw const TverException(
        '再生が拒否されました。日本国外からのアクセス、または配信期限切れの可能性があります',
      );
    }
    if (res.statusCode != 200) {
      throw TverException('再生情報の取得に失敗しました (HTTP ${res.statusCode})');
    }
    final playback = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final sources = (playback['sources'] as List?) ?? const [];
    String? streamUrl;
    Map<String, dynamic>? chosenSource;
    for (final s in sources.whereType<Map>()) {
      final src = s['src']?.toString();
      final hasDrm = s['key_systems'] != null;
      if (src != null && !hasDrm) {
        streamUrl = src;
        chosenSource = s.cast<String, dynamic>();
        break;
      }
    }
    if (streamUrl == null) {
      throw const TverException('この動画はDRM付きで配信されているため再生できません');
    }

    // SSAI sources (all simulcast/live streams) refuse manifest requests
    // until a session is registered: POST .../ssai/session {id: source.id}
    // returns query params (session=...) that must be merged into the
    // manifest URL, otherwise the gateway answers 403 (errorId E022).
    // Same flow as yt-dlp's Streaks extractor.
    if (chosenSource != null && chosenSource['ssai'] != null) {
      streamUrl = await _activateSsaiSession(
        projectId: projectId,
        streaksId: playback['id']?.toString() ?? '',
        sourceId: chosenSource['id']?.toString() ?? '',
        srcUrl: streamUrl,
      );
    }
    String? subtitleUrl;
    final tracks = (playback['tracks'] as List?) ?? const [];
    for (final t in tracks.whereType<Map>()) {
      final kind = t['kind']?.toString();
      if (kind == 'captions' || kind == 'subtitles') {
        subtitleUrl = t['src']?.toString();
        if (subtitleUrl != null) break;
      }
    }
    return (
      streamUrl: streamUrl,
      subtitleUrl: subtitleUrl,
      type: playback['type']?.toString(),
    );
  }

  /// Registers an SSAI session for a live source and merges the returned
  /// session query params into the manifest URL.
  Future<String> _activateSsaiSession({
    required String projectId,
    required String streaksId,
    required String sourceId,
    required String srcUrl,
  }) async {
    final res = await http.post(
      Uri.parse(
        'https://ssai.api.streaks.jp/v1/projects/$projectId/medias/$streaksId/ssai/session',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': _ua,
      },
      body: jsonEncode({'id': sourceId}),
    );
    if (res.statusCode != 200) {
      throw TverException('ライブ再生セッションの作成に失敗しました (HTTP ${res.statusCode})');
    }
    final decoded = jsonDecode(res.body);
    String? query;
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map) query = first['query']?.toString();
    } else if (decoded is Map) {
      query = decoded['query']?.toString();
    }
    if (query == null || query.isEmpty) return srcUrl;
    final sessionParams = Uri.splitQueryString(query);
    final uri = Uri.parse(srcUrl);
    return uri
        .replace(queryParameters: {...uri.queryParameters, ...sessionParams})
        .toString();
  }

  // ---------------------------------------------------------------------------
  // Episodes
  // ---------------------------------------------------------------------------

  Future<({String? version, String? title, String? seriesTitle})>
  _episodeMeta(String episodeId) async {
    try {
      final epJson = await _getJson(
        'https://platform-api.tver.jp/service/api/v1/callEpisode/$episodeId',
      );
      final result = (epJson['result'] as Map?)?.cast<String, dynamic>() ?? {};
      final episode = (result['episode'] as Map?)?.cast<String, dynamic>();
      final content =
          (episode?['content'] as Map?)?.cast<String, dynamic>() ?? {};
      return (
        version: content['version']?.toString(),
        title: content['title']?.toString(),
        seriesTitle: content['seriesTitle']?.toString(),
      );
    } catch (_) {
      // Metadata is best-effort; playback resolution continues.
      return (version: null, title: null, seriesTitle: null);
    }
  }

  Future<Map<String, dynamic>> _episodeStatics(
    String episodeId,
    String version,
  ) {
    return _getJsonNoSession(
      'https://statics.tver.jp/content/episode/$episodeId.json?v=$version',
      headers: {'Referer': 'https://tver.jp/', 'User-Agent': _ua},
    );
  }

  /// Resolves an episode id to a playable HLS URL (Streaks backend).
  Future<PlayInfo> resolveEpisode(String episodeId) async {
    await _ensureSession();

    // Kick off the metadata fetch and the statics fetch (with the usual
    // version) concurrently — this shaves one round trip off the
    // time-to-first-frame in the common case.
    final metaFuture = _episodeMeta(episodeId);
    Map<String, dynamic> statics;
    try {
      statics = await _episodeStatics(episodeId, '5');
    } catch (_) {
      final meta = await metaFuture;
      statics = await _episodeStatics(episodeId, meta.version ?? '5');
    }
    final meta = await metaFuture;

    final title =
        statics['title']?.toString() ?? meta.title ?? 'エピソード $episodeId';
    final description = statics['description']?.toString();

    final streaks = (statics['streaks'] as Map?)?.cast<String, dynamic>();
    if (streaks == null) {
      throw const TverException(
        'この動画は旧形式（Brightcove）で配信されているため、まだ再生できません',
      );
    }
    final projectId = streaks['projectID']?.toString();
    String? mediaId;
    final refId = streaks['videoRefID']?.toString();
    if (refId != null && refId.isNotEmpty) {
      mediaId = refId.startsWith('ref:') ? refId : 'ref:$refId';
    } else {
      mediaId = streaks['mediaID']?.toString();
    }
    if (projectId == null || mediaId == null || mediaId.isEmpty) {
      throw const TverException('再生情報が見つかりませんでした');
    }

    final pb = await _streaksPlayback(projectId, mediaId);
    return PlayInfo(
      episodeId: episodeId,
      streamUrl: pb.streamUrl,
      title: title,
      seriesTitle: meta.seriesTitle,
      description: description,
      subtitleUrl: pb.subtitleUrl,
      isLive: pb.type == 'live' || pb.type == 'linear',
    );
  }
}
