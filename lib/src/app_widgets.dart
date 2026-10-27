part of '../main.dart';

class NavikaApp extends StatelessWidget {
  const NavikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NavikaTheme>(
      valueListenable: _themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Navika',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: mode == NavikaTheme.light
              ? Brightness.light
              : Brightness.dark,
          scaffoldBackgroundColor: C.bg,
          canvasColor: C.bg,
          fontFamily: 'DMSans',
          colorScheme: ColorScheme(
            brightness: mode == NavikaTheme.light
                ? Brightness.light
                : Brightness.dark,
            primary: C.lime,
            onPrimary: C.black,
            surface: C.surface,
            onSurface: C.text,
            outline: C.border,
            error: C.danger,
            onError: Colors.white,
            primaryContainer: C.surface2,
            onPrimaryContainer: C.text,
            secondary: C.lime,
            onSecondary: C.black,
            secondaryContainer: C.surface2,
            onSecondaryContainer: C.text,
            tertiary: C.lime,
            onTertiary: C.black,
            tertiaryContainer: C.surface2,
            onTertiaryContainer: C.text,
            errorContainer: C.danger,
            onErrorContainer: Colors.white,
            surfaceContainerHighest: C.surface2,
            onSurfaceVariant: C.muted,
            inverseSurface: C.text,
            onInverseSurface: C.bg,
            inversePrimary: C.lime,
            shadow: Colors.black,
            scrim: Colors.black,
            surfaceTint: C.lime,
          ),
          textTheme: TextTheme(
            bodyLarge: TextStyle(fontFamily: 'DMSans', color: C.text),
            bodyMedium: TextStyle(fontFamily: 'DMSans', color: C.text),
            bodySmall: TextStyle(fontFamily: 'DMSans', color: C.text),
            titleLarge: TextStyle(fontFamily: 'SyneBold', color: C.text),
            headlineMedium: TextStyle(fontFamily: 'SyneBold', color: C.text),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: C.bg,
            hintStyle: TextStyle(
              color: C.muted,
              fontFamily: 'DMSans',
              fontSize: 13,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: C.lime),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: C.lime,
              foregroundColor: C.black,
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: const TextStyle(
                fontFamily: 'DMSansBold',
                fontSize: 12,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: C.text,
              side: BorderSide(color: C.border),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              textStyle: const TextStyle(
                fontFamily: 'DMSansBold',
                fontSize: 12,
              ),
            ),
          ),
          dividerColor: C.border,
          useMaterial3: true,
        ),
        home: const _StartupGate(),
      ),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    if (!_audioServiceInitializationRequired) return const HomeScreen();
    return FutureBuilder<void>(
      future: _audioServiceReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const HomeScreen();
        }
        return Scaffold(
          backgroundColor: C.bg,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'navika',
                  style: TextStyle(
                    fontFamily: 'SyneBold',
                    fontSize: 38,
                    color: C.text,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: C.lime,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NewPlaylistDialog extends StatefulWidget {
  const _NewPlaylistDialog();

  @override
  State<_NewPlaylistDialog> createState() => _NewPlaylistDialogState();
}

class _FlowSlider extends StatefulWidget {
  const _FlowSlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  State<_FlowSlider> createState() => _FlowSliderState();
}

class _FlowSliderState extends State<_FlowSlider> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant _FlowSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  void _update(double dx, double width) {
    if (width <= 0) return;
    setState(() => _value = (dx / width).clamp(0.0, 1.0));
  }

  void _finish() {
    widget.onChanged(_value);
    widget.onChangeEnd();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _update(details.localPosition.dx, width),
            onTapUp: (_) => _finish(),
            onHorizontalDragUpdate: (details) =>
                _update(details.localPosition.dx, width),
            onHorizontalDragEnd: (_) => _finish(),
            child: Center(
              child: SizedBox(
                height: 4,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: C.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: Duration(milliseconds: 60),
                      curve: Curves.easeOutCubic,
                      widthFactor: _value,
                      alignment: Alignment.centerLeft,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: C.lime,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 2,
                              decoration: BoxDecoration(
                                color: C.lime,
                                boxShadow: [
                                  BoxShadow(
                                    color: C.lime.withValues(alpha: .6),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedPositioned(
                      left: (width * _value - 7).clamp(-1.0, width - 13),
                      top: -5,
                      duration: Duration(milliseconds: 60),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: C.lime,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.bg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewPlaylistDialogState extends State<_NewPlaylistDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: C.surface,
      title: Text('New playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (value) {
          final name = value.trim();
          if (name.isNotEmpty) Navigator.pop(context, name);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
          child: Text('Create'),
        ),
      ],
    );
  }
}

class _PlaylistTrackPicker extends StatefulWidget {
  const _PlaylistTrackPicker({
    required this.tracks,
    required this.existingIds,
    required this.artwork,
  });

  final List<MusicTrack> tracks;
  final Set<String> existingIds;
  final Widget Function(MusicTrack track) artwork;

  @override
  State<_PlaylistTrackPicker> createState() => _PlaylistTrackPickerState();
}

class _PlaylistTrackPickerState extends State<_PlaylistTrackPicker> {
  final _search = TextEditingController();
  final Set<String> _selected = {};

  List<MusicTrack> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.tracks;
    return widget.tracks
        .where(
          (track) => '${track.title} ${track.artist} ${track.album}'
              .toLowerCase()
              .contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _filtered;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose tracks',
                      style: TextStyle(fontFamily: 'SyneBold', fontSize: 22),
                    ),
                  ),
                  Text(
                    '${_selected.length} selected',
                    style: TextStyle(color: C.lime, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search title, artist, or album',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    '${tracks.length} tracks',
                    style: TextStyle(color: C.muted, fontSize: 11),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed:
                        tracks
                            .where((t) => !widget.existingIds.contains(t.id))
                            .isEmpty
                        ? null
                        : () {
                            setState(() {
                              final available = tracks
                                  .where(
                                    (t) => !widget.existingIds.contains(t.id),
                                  )
                                  .map((t) => t.id);
                              if (available.every(_selected.contains)) {
                                _selected.removeAll(available);
                              } else {
                                _selected.addAll(available);
                              }
                            });
                          },
                    child: Text('Select all results'),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Text(
                        'No matching tracks',
                        style: TextStyle(color: C.muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final alreadyAdded = widget.existingIds.contains(
                          track.id,
                        );
                        final selected = _selected.contains(track.id);
                        return ListTile(
                          enabled: !alreadyAdded,
                          leading: widget.artwork(track),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            alreadyAdded
                                ? '${track.artist} · Already in playlist'
                                : '${track.artist} · ${track.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: alreadyAdded
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: C.muted,
                                  size: 20,
                                )
                              : Checkbox(
                                  value: selected,
                                  onChanged: (_) => setState(() {
                                    if (selected) {
                                      _selected.remove(track.id);
                                    } else {
                                      _selected.add(track.id);
                                    }
                                  }),
                                ),
                          onTap: alreadyAdded
                              ? null
                              : () => setState(() {
                                  if (selected) {
                                    _selected.remove(track.id);
                                  } else {
                                    _selected.add(track.id);
                                  }
                                }),
                        );
                      },
                    ),
            ),
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              widget.tracks
                                  .where(
                                    (track) => _selected.contains(track.id),
                                  )
                                  .toList(),
                            ),
                      icon: Icon(Icons.playlist_add_rounded),
                      label: Text('Add ${_selected.length} tracks'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
