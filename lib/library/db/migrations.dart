import 'package:sqflite/sqflite.dart';

/// One schema migration. Runs inside a transaction; must be additive and use
/// only SQL understood by SQLite 3.9 (Android 7 system SQLite): no UPSERT,
/// no window functions, no `ALTER TABLE ... RENAME/DROP COLUMN`.
typedef Migration = Future<void> Function(Transaction txn);

/// Ordered migrations. `migrations[i]` upgrades the schema from version `i`
/// to `i + 1`. The schema version is stored in `PRAGMA user_version`.
const List<Migration> migrations = [
  migrateV1,
  migrateV2,
  migrateV3,
];

/// Latest schema version known to this build.
int get latestSchemaVersion => migrations.length;

/// v1 — tracks, playlists, favorites, history, search history, folders.
Future<void> migrateV1(Transaction txn) async {
  await txn.execute('''
    CREATE TABLE tracks (
      id TEXT PRIMARY KEY NOT NULL,
      source_id TEXT NOT NULL,
      source_track_id TEXT NOT NULL,
      title TEXT NOT NULL,
      title_norm TEXT NOT NULL,
      artist TEXT NOT NULL DEFAULT '',
      artist_norm TEXT NOT NULL DEFAULT '',
      primary_artist TEXT NOT NULL DEFAULT '',
      album TEXT,
      album_norm TEXT,
      album_artist TEXT,
      album_artist_norm TEXT,
      genre TEXT,
      genre_norm TEXT,
      year INTEGER,
      duration_ms INTEGER,
      isrc TEXT,
      track_no INTEGER,
      disc_no INTEGER,
      artwork_url TEXT,
      search_norm TEXT NOT NULL DEFAULT '',
      local_path TEXT,
      file_size INTEGER,
      file_mtime INTEGER,
      file_hash TEXT,
      date_added INTEGER NOT NULL,
      last_seen_at INTEGER,
      json TEXT NOT NULL,
      override_json TEXT
    )''');
  await txn.execute('CREATE INDEX idx_tracks_title_norm ON tracks(title_norm)');
  await txn.execute('CREATE INDEX idx_tracks_artist_norm ON tracks(artist_norm)');
  await txn.execute('CREATE INDEX idx_tracks_album_norm ON tracks(album_norm, album_artist_norm)');
  await txn.execute('CREATE INDEX idx_tracks_genre_norm ON tracks(genre_norm)');
  await txn.execute('CREATE INDEX idx_tracks_source ON tracks(source_id)');
  await txn.execute('CREATE INDEX idx_tracks_isrc ON tracks(isrc)');
  await txn.execute('CREATE INDEX idx_tracks_local_path ON tracks(local_path)');
  await txn.execute('CREATE INDEX idx_tracks_file_hash ON tracks(file_hash)');
  await txn.execute('CREATE INDEX idx_tracks_date_added ON tracks(date_added)');

  // Every credited artist of a track (primary first), for artist pages.
  await txn.execute('''
    CREATE TABLE track_artists (
      track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      position INTEGER NOT NULL,
      name TEXT NOT NULL,
      name_norm TEXT NOT NULL,
      PRIMARY KEY (track_id, position)
    )''');
  await txn.execute('CREATE INDEX idx_track_artists_norm ON track_artists(name_norm)');

  await txn.execute('''
    CREATE TABLE playlists (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      kind TEXT NOT NULL,
      artwork_url TEXT,
      owner_name TEXT,
      source_id TEXT,
      source_playlist_id TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      auto_download INTEGER NOT NULL DEFAULT 0,
      smart_rules TEXT,
      permalink TEXT
    )''');
  await txn.execute('''
    CREATE TABLE playlist_entries (
      entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
      playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
      position INTEGER NOT NULL,
      track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      added_at INTEGER NOT NULL
    )''');
  await txn.execute('CREATE INDEX idx_entries_playlist ON playlist_entries(playlist_id, position)');
  await txn.execute('CREATE INDEX idx_entries_track ON playlist_entries(track_id)');

  await txn.execute('''
    CREATE TABLE favorites (
      track_id TEXT PRIMARY KEY NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      added_at INTEGER NOT NULL
    )''');

  await txn.execute('''
    CREATE TABLE play_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      played_at INTEGER NOT NULL,
      listened_ms INTEGER NOT NULL,
      completed INTEGER NOT NULL,
      origin TEXT
    )''');
  await txn.execute('CREATE INDEX idx_history_played_at ON play_history(played_at)');
  await txn.execute('CREATE INDEX idx_history_track ON play_history(track_id, played_at)');

  await txn.execute('''
    CREATE TABLE search_history (
      query_key TEXT PRIMARY KEY NOT NULL,
      query TEXT NOT NULL,
      searched_at INTEGER NOT NULL
    )''');

  await txn.execute('''
    CREATE TABLE library_folders (
      path TEXT PRIMARY KEY NOT NULL,
      watch INTEGER NOT NULL DEFAULT 1,
      added_at INTEGER NOT NULL,
      last_scanned_at INTEGER
    )''');
}

/// v2 — track links (cross-provider matches, playlist migration).
/// Stored once per pair in canonical order (`a < b`).
Future<void> migrateV2(Transaction txn) async {
  await txn.execute('''
    CREATE TABLE track_links (
      a TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      b TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
      confidence REAL NOT NULL,
      confirmed INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (a, b),
      CHECK (a < b)
    )''');
  await txn.execute('CREATE INDEX idx_links_b ON track_links(b)');
}

/// v3 — missing-file tracking and the downloaded-tracks index used by the
/// "Downloaded"/"Available offline" filters and smart playlists.
Future<void> migrateV3(Transaction txn) async {
  await txn.execute('ALTER TABLE tracks ADD COLUMN missing_since INTEGER');
  await txn.execute('''
    CREATE TABLE downloaded_tracks (
      track_id TEXT PRIMARY KEY NOT NULL
    )''');
}
