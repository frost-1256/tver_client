/// Content item as returned by the TVer platform API "contents" arrays.
class ContentItem {
  final String type; // episode | series | season
  final String id;
  final String title;
  final String? seriesTitle;
  final String? seriesID;
  final int? durationSec;
  final int? endAt; // unix seconds
  final String? broadcastDateLabel;
  final String? broadcasterName;
  final String? thumbnailPath;
  final int? rank;

  const ContentItem({
    required this.type,
    required this.id,
    required this.title,
    this.seriesTitle,
    this.seriesID,
    this.durationSec,
    this.endAt,
    this.broadcastDateLabel,
    this.broadcasterName,
    this.thumbnailPath,
    this.rank,
  });

  /// Parses one entry of a `contents` array: {type, content: {...}, rank}.
  factory ContentItem.fromEntry(Map<String, dynamic> entry) {
    final content = (entry['content'] as Map?)?.cast<String, dynamic>() ?? {};
    return ContentItem(
      type: entry['type']?.toString() ?? '',
      id: content['id']?.toString() ?? '',
      title: content['title']?.toString() ?? '',
      seriesTitle: content['seriesTitle']?.toString(),
      seriesID: content['seriesID']?.toString(),
      durationSec: (content['duration'] as num?)?.toInt(),
      endAt: (content['endAt'] as num?)?.toInt(),
      broadcastDateLabel: content['broadcastDateLabel']?.toString(),
      broadcasterName:
          content['broadcasterName']?.toString() ??
          content['productionProviderName']?.toString(),
      thumbnailPath: content['thumbnailPath']?.toString(),
      rank: (entry['rank'] as num?)?.toInt(),
    );
  }

  String get thumbnailUrl {
    if (thumbnailPath != null && thumbnailPath!.isNotEmpty) {
      return 'https://statics.tver.jp$thumbnailPath';
    }
    final kind = type == 'series' ? 'series' : 'episode';
    return 'https://statics.tver.jp/images/content/thumbnail/$kind/xlarge/$id.jpg';
  }

  String? get remainingLabel {
    if (endAt == null) return null;
    final end = DateTime.fromMillisecondsSinceEpoch(endAt! * 1000);
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return '配信終了';
    if (diff.inDays >= 1) return 'あと${diff.inDays}日';
    if (diff.inHours >= 1) return 'あと${diff.inHours}時間';
    return 'まもなく終了';
  }

  String? get durationLabel {
    if (durationSec == null) return null;
    final m = durationSec! ~/ 60;
    final s = durationSec! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// A titled horizontal rail of content (one ranking group).
class ContentRail {
  final String title;
  final String itemType; // episode | series
  final List<ContentItem> items;
  const ContentRail({
    required this.title,
    required this.itemType,
    required this.items,
  });
}

/// Everything needed to start playback of one episode.
class PlayInfo {
  final String episodeId;
  final String streamUrl;
  final String title;
  final String? seriesTitle;
  final String? description;
  final String? subtitleUrl;
  final bool isLive;

  const PlayInfo({
    required this.episodeId,
    required this.streamUrl,
    required this.title,
    this.seriesTitle,
    this.description,
    this.subtitleUrl,
    this.isLive = false,
  });
}

/// One simulcast (live) channel from callLiveChannel.
class LiveChannel {
  final String id; // ntv | ex | tbs | tx | cx
  final String name; // broadcaster name
  final String projectId; // Streaks project, e.g. tver-simul-ntv
  final String mediaId; // Streaks media, e.g. ref:simul-ntv

  const LiveChannel({
    required this.id,
    required this.name,
    required this.projectId,
    required this.mediaId,
  });

  factory LiveChannel.fromEntry(Map<String, dynamic> entry) {
    final content = (entry['content'] as Map?)?.cast<String, dynamic>() ?? {};
    final video = (entry['video'] as Map?)?.cast<String, dynamic>() ?? {};
    return LiveChannel(
      id: content['id']?.toString() ?? '',
      name: content['name']?.toString() ?? '',
      projectId: video['projectID']?.toString() ?? '',
      mediaId: video['mediaID']?.toString() ?? '',
    );
  }
}

/// One program on a live channel's timeline (callLiveTimeline).
class LiveProgram {
  final String liveEpisodeId;
  final String title;
  final String? seriesTitle;
  final int startAt; // unix seconds
  final int endAt; // unix seconds
  final String? thumbnailPath;

  const LiveProgram({
    required this.liveEpisodeId,
    required this.title,
    this.seriesTitle,
    required this.startAt,
    required this.endAt,
    this.thumbnailPath,
  });

  factory LiveProgram.fromEntry(Map<String, dynamic> entry) {
    final content = (entry['content'] as Map?)?.cast<String, dynamic>() ?? {};
    return LiveProgram(
      liveEpisodeId: content['id']?.toString() ?? '',
      title: content['title']?.toString() ?? '',
      seriesTitle: content['seriesTitle']?.toString(),
      startAt: (content['startAt'] as num?)?.toInt() ?? 0,
      endAt: (content['endAt'] as num?)?.toInt() ?? 0,
      thumbnailPath: content['thumbnailPath']?.toString(),
    );
  }

  bool isCurrentAt(DateTime now) {
    final s = now.millisecondsSinceEpoch ~/ 1000;
    return startAt <= s && s < endAt;
  }

  String get timeRangeLabel {
    String fmt(int unix) {
      final d = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return '${fmt(startAt)}–${fmt(endAt)}';
  }
}

/// One broadcaster row of the program guide (callEPGv2).
class EpgChannel {
  final String broadcasterId;
  final String name;
  final List<EpgProgram> programs;
  const EpgChannel({
    required this.broadcasterId,
    required this.name,
    required this.programs,
  });
}

class EpgProgram {
  final String title;
  final String seriesTitle;
  final int startAt; // unix seconds
  final int endAt; // unix seconds
  final bool isNew;

  const EpgProgram({
    required this.title,
    required this.seriesTitle,
    required this.startAt,
    required this.endAt,
    required this.isNew,
  });

  factory EpgProgram.fromJson(Map<String, dynamic> json) {
    final icon = (json['icon'] as Map?)?.cast<String, dynamic>() ?? {};
    return EpgProgram(
      title: json['title']?.toString() ?? '',
      seriesTitle: json['seriesTitle']?.toString() ?? '',
      startAt: (json['startAt'] as num?)?.toInt() ?? 0,
      endAt: (json['endAt'] as num?)?.toInt() ?? 0,
      isNew: icon['new'] == true,
    );
  }

  bool isCurrentAt(DateTime now) {
    final s = now.millisecondsSinceEpoch ~/ 1000;
    return startAt <= s && s < endAt;
  }

  String get timeRangeLabel {
    String fmt(int unix) {
      final d = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return '${fmt(startAt)}–${fmt(endAt)}';
  }
}

class TverException implements Exception {
  final String message;
  const TverException(this.message);
  @override
  String toString() => message;
}
