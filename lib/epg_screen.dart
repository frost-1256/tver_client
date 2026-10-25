import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'tver_api.dart';

/// Terrestrial program guide (callEPGv2). Programs currently on air on a
/// simulcast channel are tappable and jump straight into the live stream.
class EpgScreen extends StatefulWidget {
  final TverApi api;
  const EpgScreen({super.key, required this.api});

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  DateTime _date = DateTime.now();
  late Future<List<EpgChannel>> _future;
  List<LiveChannel> _liveChannels = const [];
  int _selectedChannel = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.api.epg(_date);
    widget.api
        .liveChannels()
        .then((chs) {
          if (mounted) setState(() => _liveChannels = chs);
        })
        .catchError((_) {});
  }

  void _shiftDay(int delta) {
    setState(() {
      _date = _date.add(Duration(days: delta));
      _future = widget.api.epg(_date);
      _selectedChannel = 0;
    });
  }

  LiveChannel? _liveChannelFor(String broadcasterName) {
    for (final ch in _liveChannels) {
      if (ch.name == broadcasterName) return ch;
    }
    return null;
  }

  String get _dateLabel {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final wd = weekdays[_date.weekday - 1];
    return '${_date.month}/${_date.day}（$wd）';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday =
        _date.year == now.year && _date.month == now.month && _date.day == now.day;
    return Scaffold(
      appBar: AppBar(
        title: const Text('番組表'),
        actions: [
          IconButton(
            onPressed: () => _shiftDay(-1),
            icon: const Icon(Icons.chevron_left),
            tooltip: '前日',
          ),
          Center(child: Text(_dateLabel, style: theme.textTheme.titleMedium)),
          IconButton(
            onPressed: () => _shiftDay(1),
            icon: const Icon(Icons.chevron_right),
            tooltip: '翌日',
          ),
        ],
      ),
      body: FutureBuilder<List<EpgChannel>>(
        future: _future,
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
          final channels = snapshot.data!;
          final idx = _selectedChannel.clamp(0, channels.length - 1);
          final channel = channels[idx];
          final liveCh = _liveChannelFor(channel.name);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    for (var i = 0; i < channels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(channels[i].name),
                          selected: i == idx,
                          onSelected: (_) =>
                              setState(() => _selectedChannel = i),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: channel.programs.length,
                  itemBuilder: (context, i) {
                    final p = channel.programs[i];
                    final current = isToday && p.isCurrentAt(now);
                    return ListTile(
                      dense: true,
                      tileColor: current
                          ? theme.colorScheme.primaryContainer
                          : null,
                      leading: SizedBox(
                        width: 96,
                        child: Text(
                          p.timeRangeLabel,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      title: Text(
                        p.title,
                        style: current
                            ? theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              )
                            : null,
                      ),
                      subtitle: p.seriesTitle.isNotEmpty
                          ? Text(p.seriesTitle)
                          : null,
                      trailing: current
                          ? const Chip(
                              label: Text('放送中'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            )
                          : (p.isNew
                                ? const Chip(
                                    label: Text('新'),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  )
                                : null),
                      onTap: current && liveCh != null
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  api: widget.api,
                                  liveChannel: liveCh,
                                  knownTitle: p.title,
                                  knownSeriesTitle: liveCh.name,
                                ),
                              ),
                            )
                          : null,
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
