part of '../main.dart';

extension _SettingsMethods on _HomeScreenState {
  Widget _settingsOverlay({required bool isMobile}) {
    final duration = _reduceMotion
        ? Duration.zero
        : Duration(milliseconds: 170);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_showSettings,
        child: AnimatedSlide(
          offset: _showSettings
              ? Offset.zero
              : (isMobile ? Offset(1, 0) : Offset(0.08, -0.02)),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _showSettings ? 1 : 0,
            duration: duration,
            child: Material(
              color: isMobile ? C.bg : Color(0x99000000),
              child: Stack(
                children: [
                  if (!isMobile)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => _updateState(() => _showSettings = false),
                        child: SizedBox.expand(),
                      ),
                    ),
                  Align(
                    alignment: isMobile ? Alignment.center : Alignment.topRight,
                    child: Container(
                      width: isMobile ? double.infinity : 390,
                      height: isMobile ? double.infinity : null,
                      constraints: isMobile
                          ? BoxConstraints.expand()
                          : BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width - 28,
                              maxHeight:
                                  MediaQuery.sizeOf(context).height - 100,
                            ),
                      margin: isMobile
                          ? EdgeInsets.zero
                          : EdgeInsets.only(top: 68, right: 14, left: 14),
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isMobile ? null : C.surface,
                        border: isMobile ? null : Border.all(color: C.border),
                        borderRadius: isMobile
                            ? BorderRadius.zero
                            : BorderRadius.circular(18),
                        boxShadow: isMobile
                            ? null
                            : [
                                BoxShadow(
                                  color: Color(0x4D000000),
                                  blurRadius: 24,
                                ),
                              ],
                      ),
                      child: Material(
                        color: isMobile ? C.bg : C.surface,
                        borderRadius: isMobile
                            ? BorderRadius.zero
                            : BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Settings',
                                          style: TextStyle(
                                            fontFamily: 'SyneBold',
                                            fontSize: 22,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Make Navika feel right.',
                                          style: TextStyle(
                                            color: C.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _updateState(
                                      () => _showSettings = false,
                                    ),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: C.muted,
                                    ),
                                  ),
                                ],
                              ),
                              _settingsSection('APPEARANCE'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Theme',
                                  style: TextStyle(
                                    fontFamily: 'DMSansMedium',
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  switch (_themeMode.value) {
                                    NavikaTheme.dark => 'Dark',
                                    NavikaTheme.amoled => 'AMOLED black',
                                    NavikaTheme.light => 'Light',
                                  },
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: DropdownButton<NavikaTheme>(
                                  value: _themeMode.value,
                                  underline: SizedBox.shrink(),
                                  borderRadius: BorderRadius.circular(12),
                                  items: [
                                    DropdownMenuItem(
                                      value: NavikaTheme.dark,
                                      child: Text('Dark'),
                                    ),
                                    DropdownMenuItem(
                                      value: NavikaTheme.amoled,
                                      child: Text('AMOLED'),
                                    ),
                                    DropdownMenuItem(
                                      value: NavikaTheme.light,
                                      child: Text('Light'),
                                    ),
                                  ],
                                  onChanged: (theme) async {
                                    if (theme == null) return;
                                    _themeMode.value = theme;
                                    final preferences =
                                        await SharedPreferences.getInstance();
                                    await preferences.setString(
                                      _themeKey,
                                      theme.name,
                                    );
                                    if (mounted) _updateState(() {});
                                  },
                                ),
                              ),
                              _settingsSection('PERFORMANCE'),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _reduceMotion,
                                activeThumbColor: C.black,
                                activeTrackColor: C.lime,
                                inactiveThumbColor: C.muted,
                                inactiveTrackColor: C.surface2,
                                title: Text(
                                  'Reduce animations',
                                  style: TextStyle(
                                    fontFamily: 'DMSansMedium',
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  'Use fewer entrance animations for a snappier feel.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                                onChanged: (value) async {
                                  _updateState(() => _reduceMotion = value);
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  await preferences.setBool(_motionKey, value);
                                },
                              ),
                              _settingsSection('PLAYBACK'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Playback speed',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Currently ${_playbackSpeed.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}×',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: DropdownButton<double>(
                                  value: _playbackSpeed,
                                  items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                                      .map(
                                        (speed) => DropdownMenuItem(
                                          value: speed,
                                          child: Text('$speed×'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (speed) {
                                    if (speed != null) {
                                      unawaited(_setPlaybackSpeed(speed));
                                    }
                                  },
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Sleep timer',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Pause playback after a set time.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.bedtime_outlined,
                                  color: C.muted,
                                ),
                                onTap: _startSleepTimer,
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _autoAdvance,
                                activeThumbColor: C.black,
                                activeTrackColor: C.lime,
                                inactiveThumbColor: C.muted,
                                inactiveTrackColor: C.surface2,
                                title: Text(
                                  'Play next track automatically',
                                  style: TextStyle(
                                    fontFamily: 'DMSansMedium',
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  'Continue through the queue when a track ends.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                                onChanged: (value) async {
                                  _updateState(() => _autoAdvance = value);
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  await preferences.setBool(
                                    _autoAdvanceKey,
                                    value,
                                  );
                                },
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _showVisualizer,
                                activeThumbColor: C.black,
                                activeTrackColor: C.lime,
                                inactiveThumbColor: C.muted,
                                inactiveTrackColor: C.surface2,
                                title: Text(
                                  'Show player visualizer',
                                  style: TextStyle(
                                    fontFamily: 'DMSansMedium',
                                    fontSize: 12,
                                  ),
                                ),
                                subtitle: Text(
                                  'Show animated bars beside the current track.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.5,
                                  ),
                                ),
                                onChanged: (value) async {
                                  _updateState(() => _showVisualizer = value);
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  await preferences.setBool(
                                    _visualizerKey,
                                    value,
                                  );
                                },
                              ),
                              _settingsSection('LIBRARY'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Refresh library',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Fetch the latest tracks from Navidrome.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: C.muted,
                                ),
                                onTap: () {
                                  _updateState(() => _showSettings = false);
                                  _loadLibrary(force: true);
                                },
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 8, bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Music folders',
                                        style: TextStyle(
                                          fontFamily: 'DMSansMedium',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Rescan music folders',
                                      onPressed: _localFolders.isEmpty
                                          ? null
                                          : () => _scanLocalFolders(
                                              showFeedback: true,
                                            ),
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _importLocalFolder,
                                      icon: Icon(
                                        Icons.create_new_folder_outlined,
                                        size: 16,
                                      ),
                                      label: Text('Add folder'),
                                    ),
                                  ],
                                ),
                              ),
                              if (_localFolders.isEmpty)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'No watched folders. Add one to scan local music when you choose.',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 10,
                                      height: 1.5,
                                    ),
                                  ),
                                )
                              else
                                ..._localFolders.map(
                                  (folder) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.folder_outlined,
                                      color: C.muted,
                                      size: 19,
                                    ),
                                    title: Text(
                                      _folderDisplayName(folder),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    subtitle: Text(
                                      folder.startsWith('saf:')
                                          ? 'Android · scans nested folders'
                                          : folder,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: C.muted,
                                        fontSize: 9,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Remove folder',
                                      onPressed: () =>
                                          _removeLocalFolder(folder),
                                      icon: Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: C.danger,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Server connection',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  _connected
                                      ? (_credentials?.baseUrl ?? '')
                                      : 'Connect to a Navidrome server',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: C.muted,
                                ),
                                onTap: () {
                                  _updateState(() => _showSettings = false);
                                  _selectTab(AppTab.library);
                                },
                              ),
                              _settingsSection('PERSONAL TASTE'),
                              Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Navika learns from your listening history, favorites, and feedback. Explicit feedback is saved only on this device and influences Flow.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                              ..._tasteTopArtists().map(
                                (artist) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    artist.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  subtitle: Text(
                                    '${artist.plays} plays${artist.feedback == 0
                                        ? ''
                                        : artist.feedback > 0
                                        ? ' · you like this artist'
                                        : ' · lower priority'}',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  trailing: artist.feedback == 0
                                      ? Icon(
                                          Icons.graphic_eq_rounded,
                                          color: C.muted,
                                          size: 17,
                                        )
                                      : Icon(
                                          artist.feedback > 0
                                              ? Icons.thumb_up_alt_rounded
                                              : Icons.thumb_down_alt_rounded,
                                          color: artist.feedback > 0
                                              ? C.lime
                                              : C.danger,
                                          size: 17,
                                        ),
                                ),
                              ),
                              if (_tasteTopArtists().isEmpty)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'Your profile will take shape as you listen and give feedback.',
                                    style: TextStyle(
                                      color: C.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Reset personal taste profile',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Clear your More/Less like this feedback. Listening history and favorites stay intact.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.restart_alt_rounded,
                                  color: C.danger,
                                  size: 19,
                                ),
                                onTap: () async {
                                  await _resetTasteProfile();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Personal taste feedback reset.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              _settingsSection('YOUR DATA'),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Clear listening history',
                                  style: TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'Remove locally stored listening history and stats.',
                                  style: TextStyle(
                                    color: C.muted,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.close_rounded,
                                  color: C.danger,
                                  size: 18,
                                ),
                                onTap: () async {
                                  _updateState(() {
                                    _history.clear();
                                    _showSettings = false;
                                  });
                                  final preferences =
                                      await SharedPreferences.getInstance();
                                  await preferences.remove(_historyKey);
                                },
                              ),
                              if (_connected)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.logout_rounded,
                                    color: C.danger,
                                    size: 18,
                                  ),
                                  title: Text(
                                    'Disconnect server',
                                    style: TextStyle(
                                      color: C.danger,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () {
                                    _updateState(() => _showSettings = false);
                                    _logout();
                                  },
                                ),
                              SizedBox(height: 12),
                              Text(
                                'Navika · Your listening history stays on this device.',
                                style: TextStyle(
                                  color: C.muted,
                                  fontSize: 9,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsSection(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 17, bottom: 5),
      child: Text(
        title,
        style: TextStyle(
          color: C.lime,
          fontFamily: 'DMSansBold',
          fontSize: 9,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}
