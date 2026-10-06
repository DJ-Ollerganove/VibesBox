import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rb_now_playing/dj_library_prefs.dart';
import 'package:rb_now_playing/dj_sqlite.dart';
import 'package:rb_now_playing/djay_library.dart';
import 'package:rb_now_playing/engine_dj_library.dart';
import 'package:rb_now_playing/library_match.dart';
import 'package:rb_now_playing/library_store.dart';
import 'package:rb_now_playing/mix_compat.dart';
import 'package:rb_now_playing/mixxx_library.dart';
import 'package:rb_now_playing/rekordbox_cipher.dart';
import 'package:rb_now_playing/serato_library.dart';
import 'package:rb_now_playing/song_catalog.dart';
import 'package:rb_now_playing/song_track_id.dart';
import 'package:rb_now_playing/tool_gate.dart';
import 'package:rb_now_playing/tool_session.dart';
import 'package:rb_now_playing/tool_gate_strings.dart';
import 'package:rb_now_playing/tool_i18n.dart';
import 'package:rb_now_playing/tool_packs.dart';
import 'package:rb_now_playing/traktor_library.dart';
import 'package:rb_now_playing/virtualdj_library.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('entpackt den Rekordbox-SQLCipher-Schlüssel', () {
    final key = rekordboxSqlCipherKey();
    expect(key.startsWith('402fd'), isTrue);
    expect(key.length, 64);
  });

  test('wählt bei mehreren Versionen den mit den meisten Plays', () {
    final index = LibraryIndex([
      LibraryTrack(
        id: '1',
        title: 'Danza Kuduro (Radio Edit)',
        artist: 'Don Omar',
        playCount: 12,
      ),
      LibraryTrack(
        id: '2',
        title: 'Danza Kuduro',
        artist: 'Don Omar feat. Lucenzo',
        playCount: 114,
      ),
      LibraryTrack(
        id: '3',
        title: 'Danza Kuduro (Club Mix)',
        artist: 'Don Omar',
        playCount: 3,
      ),
    ]);
    final hit = index.match('Danza Kuduro', 'Don Omar');
    expect(hit?.id, '2');
    expect(hit?.playCount, 114);
  });

  test('erkennt Tippfehler und Klammern im Titel', () {
    final index = LibraryIndex([
      LibraryTrack(
        id: '1',
        title: 'Waka Waka (This Time For Africa)',
        artist: 'Shakira',
        playCount: 110,
      ),
    ]);
    final hit = index.match('Waka Waka', 'Shakira');
    expect(hit?.id, '1');
  });

  test('verwechselt keine kurzen Titel', () {
    final index = LibraryIndex([
      LibraryTrack(id: '1', title: 'Love', artist: 'Unknown', playCount: 9),
      LibraryTrack(
        id: '2',
        title: 'Love Me Like You Do',
        artist: 'Ellie Goulding',
        playCount: 40,
      ),
    ]);
    expect(index.match('Love Me Like You Do', 'Ellie Goulding')?.id, '2');
    expect(index.match('Love', 'Unknown')?.id, '1');
  });

  test('verknüpft Kerstin Ott mit Stereoact feat./x/und', () {
    final index = LibraryIndex([
      LibraryTrack(
        id: 'feat',
        title: 'Die immer lacht',
        artist: 'Stereoact feat. Kerstin Ott',
        playCount: 20,
      ),
    ]);
    expect(index.match('Die immer lacht', 'Kerstin Ott')?.id, 'feat');

    final withX = LibraryIndex([
      LibraryTrack(
        id: 'x',
        title: 'Die immer lacht (Stereoact Remix)',
        artist: 'Stereoact x Kerstin Ott',
        playCount: 8,
      ),
    ]);
    expect(withX.match('Die immer lacht', 'Kerstin Ott')?.id, 'x');

    final withAnd = LibraryIndex([
      LibraryTrack(
        id: 'and',
        title: 'Die immer lacht',
        artist: 'Stereoact & Kerstin Ott',
        playCount: 3,
      ),
    ]);
    expect(withAnd.match('Die immer lacht', 'Kerstin Ott')?.id, 'and');
  });

  test('normalisiert Track-IDs und Versionen', () {
    final id = trackIdentityOf(
      artist: 'Toto',
      title: 'Africa (Extended Mix)',
    );
    expect(id.version, 'Extended Mix');
    expect(id.title, 'Africa');
    expect(id.id, 'toto_africa_extended_mix');
    expect(
      trackIdentityOf(artist: 'ABBA', title: 'SOS').version,
      'Original',
    );
    expect(
      suggestionCacheDocId(
        artist: 'Toto',
        title: 'Africa',
        scope: 'strict',
        familiarity: 'hits',
        allowSameArtist: true,
      ),
      isNot(
        suggestionCacheDocId(
          artist: 'Toto',
          title: 'Africa',
          scope: 'similar',
          familiarity: 'hits',
          allowSameArtist: true,
        ),
      ),
    );
  });

  test('sortiert passende Songs nach echten Folgesongs', () {
    final ranked = rankByPlayedAfter(
      pool: [
        {'title': 'KI Eins', 'artist': 'A'},
        {'title': 'KI Zwei', 'artist': 'B'},
      ],
      playedAfter: [
        {'title': 'KI Zwei', 'artist': 'B', 'playedAfter': 12},
        {'title': 'KI Eins', 'artist': 'A', 'playedAfter': 3},
        {
          'title': 'Techno Fremd',
          'artist': 'X',
          'playedAfter': 80,
          'bpm': 140,
          'camelot': '1A',
        },
      ],
      seedBpm: 92,
      seedCamelot: '8B',
      scope: 'strict',
    );
    expect(
      ranked.map((e) => e['title']),
      ['KI Zwei', 'KI Eins'],
    );
  });

  test('nimmt nur mischbare Extra-Übergänge in den Pool', () {
    final ranked = rankByPlayedAfter(
      pool: [
        {'title': 'KI Eins', 'artist': 'A'},
      ],
      playedAfter: [
        {
          'title': 'Praxis Hit',
          'artist': 'C',
          'playedAfter': 20,
          'bpm': 94,
          'camelot': '8A',
        },
        {
          'title': 'Ohne Meta',
          'artist': 'D',
          'playedAfter': 50,
        },
      ],
      seedBpm: 92,
      seedCamelot: '8B',
      scope: 'similar',
    );
    expect(
      ranked.map((e) => e['title']),
      ['Praxis Hit', 'KI Eins'],
    );
  });

  test('erkennt mischbare BPM und Camelot', () {
    expect(
      fitsMixWindow(
        seedBpm: 92,
        seedCamelot: '8B',
        candidateBpm: 94,
        candidateCamelot: '8A',
        scope: 'strict',
      ),
      isTrue,
    );
    expect(
      fitsMixWindow(
        seedBpm: 92,
        seedCamelot: '8B',
        candidateBpm: 140,
        candidateCamelot: '1A',
        scope: 'strict',
      ),
      isFalse,
    );
    expect(mixBpmWindow('strict'), 6);
    expect(mixBpmWindow('similar'), 12);
  });

  test('Tidal-Bibliothekspfad ist nicht ziehbar', () {
    final track = LibraryTrack(
      id: 't1',
      title: 'Africa',
      artist: 'Toto',
      location: 'tidal:tracks:80333251',
    );
    expect(track.isTidal, isTrue);
    expect(track.canDragToRekordbox, isFalse);
    expect(isRekordboxDragPath('/tmp/song.mp3'), isTrue);
    expect(isRekordboxDragPath(r'C:\Music\song.mp3'), isTrue);
    expect(isRekordboxDragPath('tidal:tracks:1'), isFalse);
    expect(isRekordboxDragPath('https://tidal.com/track/1'), isFalse);
    expect(toDragLocation('streaming://tidal/123'), 'tidal:tracks:123');
    expect(toDragLocation('https://tidal.com/browse/track/99'), 'tidal:tracks:99');
    expect(toDragLocation('/Music/a.mp3'), '/Music/a.mp3');
  });

  test('erkennt die DJ-Systeme mit Bibliothek und History', () {
    expect(DjSoftware.tryParse('Rekordbox'), DjSoftware.rekordbox);
    expect(DjSoftware.tryParse('serato dj pro')?.label, 'Serato DJ Pro');
    expect(DjSoftware.tryParse('virtual dj'), DjSoftware.virtualDj);
    expect(DjSoftware.tryParse('Traktor Pro'), DjSoftware.traktor);
    expect(DjSoftware.tryParse('mixxx'), DjSoftware.mixxx);
    expect(DjSoftware.tryParse('Engine DJ'), DjSoftware.engineDj);
    expect(DjSoftware.tryParse('djay'), DjSoftware.djayPro);
    expect(DjSoftware.tryParse('DJAY Pro')?.label, 'DJAY Pro');
    expect(DjSoftware.tryParse('algoriddim djay pro'), DjSoftware.djayPro);
    expect(DjSoftware.tryParse('ableton'), isNull);
    expect(DjSoftware.tryParse('cross dj'), isNull);
    expect(DjSoftware.tryParse('ultramixer'), isNull);
    expect(
      DjSoftware.values.map((e) => e.label).toList(),
      [
        'DJAY Pro',
        'Engine DJ',
        'Mixxx',
        'Rekordbox',
        'Serato DJ Pro',
        'Traktor Pro',
        'Virtual DJ',
      ],
    );
  });

  test('hat in jeder Sprache dieselben Texte', () {
    final keys = toolPacks['de']!.keys.toSet();
    expect(toolPacks.keys.toSet(), {
      'de', 'en', 'es', 'fr', 'it', 'pt', 'nl', 'pl', 'cs', 'tr',
      'ru', 'uk', 'el', 'ar', 'hi', 'ja', 'zh', 'th', 'vi', 'sq',
    });
    for (final entry in toolPacks.entries) {
      expect(entry.value.keys.toSet(), keys, reason: entry.key);
    }
    expect(toolLanguages.length, toolPacks.length);
    expect(toolIsRtl('ar'), isTrue);
    expect(toolIsRtl('de'), isFalse);
    expect(toolLanguageForDevice('de_DE'), 'de');
    expect(toolLanguageForDevice('pt-BR'), 'pt');
    expect(toolLanguageForDevice('zh_Hans_CN'), 'zh');
    expect(toolLanguageForDevice('sv_SE'), 'en');
    expect(toolLanguageForDevice(''), 'en');
  });

  test('Startbildschirm hat in jeder Sprache dieselben Texte', () {
    final keys = toolGatePacks['de']!.keys.toSet();
    expect(toolGatePacks.keys.toSet(), toolPacks.keys.toSet());
    for (final entry in toolGatePacks.entries) {
      expect(entry.value.keys.toSet(), keys, reason: entry.key);
    }
    expect(compareSyncVersions('1.0.1', '1.0.2') < 0, isTrue);
    expect(compareSyncVersions('1.0.1+1', '1.0.1'), 0);
    expect(compareSyncVersions('1.0.2', '1.0.1') > 0, isTrue);
    expect(kSyncToolVersion, '1.0.3');
    expect(formatToolDevice('macos', 'Version 26.6.2 (Build 25G83)'), 'macOS 26.6.2');
    expect(formatToolDevice('windows', '10.0.22631'), 'Windows 11');
    expect(formatToolDevice('windows', '10.0.19045'), 'Windows 10');
    expect(
      formatToolDevice('windows', '"Windows 10 Pro" 10.0 (Build 22631)'),
      'Windows 11',
    );
    expect(
      formatToolDevice('windows', '"Windows 10 Pro" 10.0 (Build 19045)'),
      'Windows 10',
    );
  });

  test('erkennt Windows-Datei-Locks als transient', () {
    expect(
      isTransientSqliteLockError(
        const FileSystemException(
          'copy failed',
          r'C:\Pioneer\master.db',
          OSError('Sharing violation', 32),
        ),
      ),
      isTrue,
    );
    expect(
      isTransientSqliteLockError(StateError('database is locked')),
      isTrue,
    );
    expect(
      isTransientSqliteLockError(StateError('no such table')),
      isFalse,
    );
    var tries = 0;
    final value = withSqliteRetry(() {
      tries++;
      if (tries < 3) {
        throw const FileSystemException(
          'busy',
          'x',
          OSError('Sharing violation', 32),
        );
      }
      return 42;
    }, maxAttempts: 5, baseDelay: Duration.zero);
    expect(value, 42);
    expect(tries, 3);
  });

  test('SQLite-Kopie entfernt verwaiste WAL und öffnet live zuerst', () {
    final dir = Directory.systemTemp.createTempSync('sqlcopyvb');
    final src = File('${dir.path}/master.db');
    final db = sqlite3.open(src.path);
    db.execute('CREATE TABLE t (id INTEGER); INSERT INTO t VALUES (1);');
    db.execute('INSERT INTO t VALUES (2);');
    db.close();
    // Simulierte WAL neben der Hauptdatei (wie bei laufendem Rekordbox).
    File('${src.path}-wal').writeAsBytesSync(const [1, 2, 3, 4]);

    final copyPath = copySqliteForRead(src.path, 'test_master_copy.db');
    expect(File(copyPath).existsSync(), isTrue);
    expect(File('$copyPath-wal').existsSync(), isTrue);

    // Quelle ohne WAL → Ziel-WAL löschen (keine Mischung alt/neu).
    File('${src.path}-wal').deleteSync();
    final copyPath2 = copySqliteForRead(src.path, 'test_master_copy.db');
    expect(File('$copyPath2-wal').existsSync(), isFalse);

    final live = ReadonlySqlite();
    final opened = live.ensure(src.path, 'unused_copy.db');
    expect(live.openedViaCopy, isFalse);
    expect(opened.select('SELECT count(*) AS n FROM t').first['n'], 2);
    live.close();
    dir.deleteSync(recursive: true);
  });

  test('legt Bibliothekscache je DJ-Software an', () {
    expect(libraryCacheFileName('rekordbox'), 'library_rekordbox.json');
    expect(libraryCacheFileName('serato'), 'library_serato.json');
    expect(libraryCacheFileName('traktor'), 'library_traktor.json');
    expect(libraryCacheFileName('mixxx'), 'library_mixxx.json');
    expect(libraryCacheFileName('enginedj'), 'library_enginedj.json');
    expect(libraryCacheFileName('virtualdj'), 'library_virtualdj.json');
    expect(libraryCacheFileName('djaypro'), 'library_djaypro.json');
    expect(libraryCacheFileName(null), 'library.json');
  });

  test('zeigt die Standardpfade der Bibliotheken', () {
    expect(defaultLibraryPath(DjSoftware.rekordbox).toLowerCase(), contains('rekordbox'));
    expect(defaultLibraryPath(DjSoftware.serato), contains('_Serato_'));
    expect(defaultLibraryPath(DjSoftware.virtualDj), contains('VirtualDJ'));
    expect(defaultLibraryPath(DjSoftware.traktor), contains('Native Instruments'));
    expect(defaultLibraryPath(DjSoftware.mixxx).toLowerCase(), contains('mixxx'));
    expect(defaultLibraryPath(DjSoftware.engineDj), contains('Engine Library'));
    expect(defaultLibraryPath(DjSoftware.djayPro), contains('MediaLibrary.db'));
    expect(defaultLibraryPath(DjSoftware.djayPro), contains('djay'));
  });

  test('parst Serato database V2', () {
    Uint8List field(String tag, Uint8List data) {
      final out = BytesBuilder();
      out.add(tag.codeUnits);
      final len = ByteData(4)..setUint32(0, data.length);
      out.add(len.buffer.asUint8List());
      out.add(data);
      return out.toBytes();
    }

    Uint8List u16(String text) {
      final out = BytesBuilder();
      for (final unit in text.codeUnits) {
        out.addByte((unit >> 8) & 0xff);
        out.addByte(unit & 0xff);
      }
      return out.toBytes();
    }

    final track = BytesBuilder()
      ..add(field('tsng', u16('Africa')))
      ..add(field('tart', u16('Toto')))
      ..add(field('tbpm', u16('93.00')))
      ..add(field('tkey', u16('B')))
      ..add(field('pfil', u16('Users/dj/Music/Africa.mp3')))
      ..add(field('utpc', Uint8List.fromList([0, 0, 0, 12])));
    final file = BytesBuilder()
      ..add(field('vrsn', u16('2.0/Serato')))
      ..add(field('otrk', track.toBytes()));
    final tracks = parseSeratoDatabaseV2(Uint8List.fromList(file.toBytes()));
    expect(tracks, hasLength(1));
    expect(tracks.first.title, 'Africa');
    expect(tracks.first.artist, 'Toto');
    expect(tracks.first.bpm, 93);
    expect(tracks.first.playCount, 12);
    expect(tracks.first.location, '/Users/dj/Music/Africa.mp3');
  });

  test('macht aus Serato-Tidal-URIs ziehbarere Pfade', () {
    expect(seratoPortableToPath('streaming://tidal/123'), 'tidal:tracks:123');
    expect(seratoPortableToPath('Users/a/b.mp3'), '/Users/a/b.mp3');
  });

  test('parst Virtual-DJ-XML und BPM-Periode', () {
    expect(virtualDjBpm('0.5'), 120);
    expect(virtualDjBpm('128'), 128);
    const xml = '''
<VirtualDJ_Database>
 <Song FilePath="/Music/a.mp3">
  <Tags Author="ABBA" Title="SOS" Bpm="0.5" Key="Dm" />
  <Infos SongLength="200" PlayCount="4" />
 </Song>
</VirtualDJ_Database>
''';
    final tracks = parseVirtualDjDatabase(xml);
    expect(tracks, hasLength(1));
    expect(tracks.first.title, 'SOS');
    expect(tracks.first.artist, 'ABBA');
    expect(tracks.first.bpm, 120);
    expect(tracks.first.playCount, 4);
    expect(tracks.first.location, '/Music/a.mp3');
  });

  test('parst Virtual-DJ-History-M3U', () {
    const m3u = '''
#EXTM3U
#EXTINF:180,Toto - Africa
/Music/africa.mp3
#EXTINF:200,ABBA - SOS
/Music/sos.mp3
''';
    final tracks = parseVirtualDjM3u(m3u);
    expect(tracks.first.title, 'SOS');
    expect(tracks.first.artist, 'ABBA');
    expect(tracks.first.location, '/Music/sos.mp3');
    expect(tracks.last.title, 'Africa');
    expect(tracks.last.location, '/Music/africa.mp3');
  });

  test('parst Traktor-collection.nml und History-PRIMARYKEY', () {
    expect(
      traktorLocationToPath(
        volume: 'Macintosh HD',
        dir: '/:Users/:dj/:Music/:',
        file: 'Africa.mp3',
      ),
      '/Users/dj/Music/Africa.mp3',
    );
    expect(
      traktorLocationToPath(volume: 'Tidal', dir: '/:', file: '80333251'),
      'tidal:tracks:80333251',
    );
    const nml = '''
<NML VERSION="19">
<COLLECTION ENTRIES="1">
<ENTRY TITLE="Africa" ARTIST="Toto">
<LOCATION DIR="/:Music/:" FILE="Africa.mp3" VOLUME="Macintosh HD"></LOCATION>
<INFO PLAYCOUNT="9" PLAYTIME="295" KEY="B" LAST_PLAYED="2026/9/22"></INFO>
<TEMPO BPM="93"></TEMPO>
</ENTRY>
</COLLECTION>
</NML>
''';
    final tracks = parseTraktorCollection(nml);
    expect(tracks, hasLength(1));
    expect(tracks.first.title, 'Africa');
    expect(tracks.first.playCount, 9);
    expect(tracks.first.location, '/Music/Africa.mp3');
    const history = '''
<NML>
<PLAYLISTS>
<NODE>
<ENTRY><PRIMARYKEY TYPE="TRACK" KEY="Macintosh HD/:Music/:SOS.mp3"></PRIMARYKEY></ENTRY>
<ENTRY><PRIMARYKEY TYPE="TRACK" KEY="Macintosh HD/:Music/:Africa.mp3"></PRIMARYKEY></ENTRY>
</NODE>
</PLAYLISTS>
</NML>
''';
    final played = parseTraktorHistoryNml(history);
    expect(played.first.title, 'Africa');
    expect(played.first.location, '/Music/Africa.mp3');
    expect(played.last.title, 'SOS');
    expect(played.last.location, '/Music/SOS.mp3');
  });

  test('baut Engine-DJ-Pfade und Tidal-URIs', () {
    expect(
      engineAbsolutePath('/Music/Engine Library', 'Folder/a.mp3', 'a.mp3'),
      '/Music/Engine Library/Folder/a.mp3',
    );
    expect(
      engineAbsolutePath('/x', 'tidal://track/55', 'x'),
      'tidal:tracks:55',
    );
  });

  test('liest Mixxx-Bibliothek und SET_LOG-History', () {
    final dir = Directory.systemTemp.createTempSync('mixxxvb');
    final path = '${dir.path}/mixxxdb.sqlite';
    final db = sqlite3.open(path);
    db.execute('''
CREATE TABLE library (
  id INTEGER PRIMARY KEY,
  title TEXT, artist TEXT, bpm REAL, key TEXT,
  duration FLOAT, timesplayed INTEGER, location INTEGER,
  mixxx_deleted INTEGER, url TEXT, last_played_at TEXT
);
CREATE TABLE track_locations (id INTEGER PRIMARY KEY, location TEXT);
CREATE TABLE Playlists (
  id INTEGER PRIMARY KEY, name TEXT, hidden INTEGER, date_modified TEXT
);
CREATE TABLE PlaylistTracks (
  id INTEGER PRIMARY KEY, playlist_id INTEGER, track_id INTEGER,
  position INTEGER, pl_datetime_added TEXT
);
INSERT INTO track_locations VALUES (1, '/Music/africa.mp3');
INSERT INTO library VALUES (1, 'Africa', 'Toto', 93, 'B', 295, 12, 1, 0, NULL, '2026-09-22 12:00:00');
INSERT INTO Playlists VALUES (1, '2026-09-22', 2, '2026-09-22 12:00:00');
INSERT INTO PlaylistTracks VALUES (1, 1, 1, 1, '2026-09-22 12:00:00');
''');
    db.close();
    final source = MixxxLibrarySource(path);
    final tracks = source.readLibrary();
    expect(tracks, hasLength(1));
    expect(tracks.first.title, 'Africa');
    expect(tracks.first.playCount, 12);
    expect(tracks.first.location, '/Music/africa.mp3');
    expect(source.readHistory().nowPlaying?.title, 'Africa');
    source.close();
    dir.deleteSync(recursive: true);
  });

  test('liest Engine-DJ-Track und HistorylistEntity', () {
    final dir = Directory.systemTemp.createTempSync('enginevb');
    final path = '${dir.path}/m.db';
    final db = sqlite3.open(path);
    db.execute('''
CREATE TABLE Track (
  id INTEGER PRIMARY KEY, title TEXT, artist TEXT, bpm REAL,
  key TEXT, length INTEGER, playCount INTEGER, path TEXT, filename TEXT, uri TEXT
);
CREATE TABLE HistorylistEntity (
  id INTEGER PRIMARY KEY, listId INTEGER, trackId INTEGER, startTime INTEGER
);
INSERT INTO Track VALUES (1, 'Africa', 'Toto', 93, 'B', 295, 4, 'Folder/africa.mp3', 'africa.mp3', NULL);
INSERT INTO HistorylistEntity VALUES (1, 1, 1, 1750000000);
''');
    db.close();
    final source = EngineDjLibrarySource(path);
    final tracks = source.readLibrary();
    expect(tracks.first.title, 'Africa');
    expect(tracks.first.playCount, 4);
    expect(tracks.first.location, endsWith('Folder/africa.mp3'));
    final history = source.readHistory();
    expect(history.nowPlaying?.title, 'Africa');
    expect(history.nowPlaying?.bpm, 93);
    expect(history.nowPlaying?.musicalKey, 'B');
    expect(history.nowPlaying?.location, endsWith('Folder/africa.mp3'));
    source.close();
    dir.deleteSync(recursive: true);
  });

  test('liest DJAY-Pro MediaLibrary.db mit TSAF-Blobs', () {
    final dir = Directory.systemTemp.createTempSync('djayvb');
    final path = '${dir.path}/MediaLibrary.db';
    const titleId = '0123456789abcdef0123456789abcdef';
    final titleBlob = _djayTsaf([
      ..._djayClass('ADCMediaItemTitleID'),
      ..._djayStringField(titleId, 'uuid'),
      ..._djayStringField('Africa', 'title'),
      ..._djayStringField('Toto', 'artist'),
      ..._djayDoubleField(295.0, 'duration'),
    ]);
    final analyzedBlob = _djayTsaf([
      ..._djayClass('ADCMediaItemAnalyzedData'),
      ..._djayStringField(titleId, 'uuid'),
      ..._djayDoubleField(93.0, 'bpm'),
      ..._djayDoubleField(23.0, 'keySignatureIndex'),
    ]);
    final userBlob = _djayTsaf([
      ..._djayClass('ADCMediaItemUserData'),
      ..._djayStringField(titleId, 'uuid'),
      ..._djayDoubleField(7.0, 'playCount'),
    ]);
    final locBlob = _djayTsaf([
      ..._djayClass('ADCMediaItemLocation'),
      ..._djayStringField(titleId, 'uuid'),
      ..._djaySourceUris(['file:///Music/africa.mp3']),
    ]);
    final historyBlob = _djayTsaf([
      ..._djayClass('ADCHistorySessionItem'),
      ..._djayStringField('item-1', 'uuid'),
      ..._djayClass('ADCMediaItemTitleID'),
      ..._djayStringField(titleId, 'uuid'),
      ..._djayStringField('Africa', 'title'),
      ..._djayStringField('Toto', 'artist'),
      ..._djayDoubleField(295.0, 'duration'),
      0x08, ...'titleID'.codeUnits, 0x00,
      ..._djayDoubleField(1.0, 'deckNumber'),
      ..._djayDateField(0.0, 'startTime'),
    ]);
    final db = sqlite3.open(path);
    db.execute('''
CREATE TABLE database2 (
  rowid INTEGER PRIMARY KEY,
  collection CHAR NOT NULL,
  key CHAR NOT NULL,
  data BLOB,
  metadata BLOB
);
''');
    db.execute(
      'INSERT INTO database2 (collection, key, data) VALUES (?, ?, ?)',
      ['mediaItemTitleIDs', titleId, titleBlob],
    );
    db.execute(
      'INSERT INTO database2 (collection, key, data) VALUES (?, ?, ?)',
      ['mediaItemAnalyzedData', titleId, analyzedBlob],
    );
    db.execute(
      'INSERT INTO database2 (collection, key, data) VALUES (?, ?, ?)',
      ['mediaItemUserData', titleId, userBlob],
    );
    db.execute(
      'INSERT INTO database2 (collection, key, data) VALUES (?, ?, ?)',
      ['localMediaItemLocations', titleId, locBlob],
    );
    db.execute(
      'INSERT INTO database2 (collection, key, data) VALUES (?, ?, ?)',
      ['historySessionItems', 'item-1', historyBlob],
    );
    db.close();

    expect(extractDjayString(titleBlob, 'title'), 'Africa');
    // keySignatureIndex-Map = what's-now-playing KEY_SIGNATURE_MAP
    expect(djayKeyName(0), 'Db');
    expect(djayKeyName(1), 'Bbm');
    expect(djayKeyName(8), 'F');
    expect(djayKeyName(22), 'C');
    expect(djayKeyName(23), 'Am');
    expect(resolveDjayUri('file:///Music/africa.mp3'), '/Music/africa.mp3');
    expect(
      resolveDjayUri('file:///D:/Music/africa.mp3', windows: true),
      r'D:\Music\africa.mp3',
    );
    expect(
      resolveDjayUri(r'file:///D:%5CMusic%5Cafrica.mp3', windows: true),
      r'D:\Music\africa.mp3',
    );
    expect(resolveDjayUri('file:///'), isNull);

    final source = DjayLibrarySource(path);
    final tracks = source.readLibrary();
    expect(tracks, hasLength(1));
    expect(tracks.first.title, 'Africa');
    expect(tracks.first.artist, 'Toto');
    expect(tracks.first.bpm, 93);
    expect(tracks.first.musicalKey, 'Am');
    expect(tracks.first.playCount, 7);
    expect(tracks.first.location, '/Music/africa.mp3');
    final history = source.readHistory();
    expect(history.nowPlaying?.title, 'Africa');
    expect(history.nowPlaying?.bpm, 93);
    expect(history.nowPlaying?.musicalKey, 'Am');
    expect(history.nowPlaying?.location, '/Music/africa.mp3');
    expect(source.libraryPulse().trackCount, 1);
    expect(source.libraryPulse().playSum, 7);
    source.close();
    dir.deleteSync(recursive: true);
  });
}

Uint8List _djayTsaf(List<int> body) {
  final out = BytesBuilder();
  out.add([0x54, 0x53, 0x41, 0x46]); // TSAF
  out.add(List<int>.filled(16, 0));
  out.add(body);
  return out.toBytes();
}

List<int> _djayClass(String name) => [0x2b, 0x08, ...name.codeUnits, 0x00];

List<int> _djayStringField(String value, String key) => [
      0x08,
      ...value.codeUnits,
      0x00,
      0x08,
      ...key.codeUnits,
      0x00,
    ];

List<int> _djayDoubleField(double value, String key) {
  final bytes = ByteData(8)..setFloat64(0, value, Endian.little);
  return [
    ...bytes.buffer.asUint8List(),
    0x08,
    ...key.codeUnits,
    0x00,
  ];
}

List<int> _djayDateField(double cfAbsolute, String key) =>
    _djayDoubleField(cfAbsolute, key);

List<int> _djaySourceUris(List<String> uris) {
  final out = <int>[];
  for (final uri in uris) {
    out.addAll([0x21, 0x08, ...uri.codeUnits, 0x00]);
  }
  out.addAll([0x08, ...'sourceURIs'.codeUnits, 0x00]);
  return out;
}
