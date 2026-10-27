import 'dart:io';

import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/downloads/artwork/fermata_artwork_cache.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_server.dart';

void main() {
  late Directory root;
  late AppPaths paths;
  late SettingsStore settings;
  late TestAudioServer server;
  late FermataHttp http;
  final caches = <FermataArtworkCache>[];

  FermataArtworkCache create() {
    final c = FermataArtworkCache(paths: paths, settings: settings, http: http);
    caches.add(c);
    return c;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fermata_art_');
    paths = AppPaths.forTesting(root);
    settings = SettingsStore.inMemory(
        const AppSettings().copyWith(storage: const StorageSettings(artworkCacheMb: 1)));
    server = await TestAudioServer.start();
    http = FermataHttp();
  });

  tearDown(() async {
    for (final c in caches) {
      await c.dispose();
    }
    caches.clear();
    await server.close();
    http.close();
    await root.delete(recursive: true);
  });

  test('is a CacheManager rooted in <artworkCacheDir>/remote', () async {
    final cache = create();
    expect(cache, isA<BaseCacheManager>());
    expect(cache.root.path, p.join(paths.artworkCacheDir.path, 'remote'));
    final url = server.add('a.png', ServedFile(tinyPng, contentType: 'image/png'));
    final file = await cache.getSingleFile(url.toString());
    expect(p.isWithin(cache.root.path, file.path), isTrue);
    expect(await file.readAsBytes(), tinyPng);
    expect(await cache.sizeBytes(), greaterThanOrEqualTo(tinyPng.length));
  });

  test('pin downloads once, survives restarts and rejects non-images', () async {
    final cache = create();
    final url = server.add('cover.png', ServedFile(tinyPng, contentType: 'image/png'));
    expect(await cache.pin(url), isTrue);
    expect(await cache.pin(url), isTrue);
    expect(server.file('cover.png').requests, 1);
    expect(cache.isPinned(url), isTrue);
    await cache.dispose();
    caches.remove(cache);

    final again = create();
    // Bulk operations right after start-up must not treat indexed files as orphans.
    await again.clearUnpinned();
    expect(again.isPinned(url), isTrue);
    expect(await again.getFileFromCache(url.toString()), isNotNull);

    final html = server.add('login', ServedFile(htmlPage(), contentType: 'text/html'));
    expect(await again.pin(html), isFalse);
    expect(again.isPinned(html), isFalse);
    expect(await again.pin(Uri.parse('file:///tmp/x.jpg')), isFalse);
  });

  test('byte budget (storage.artworkCacheMb) evicts LRU unpinned entries, never pinned ones', () async {
    final cache = create();
    final pinnedUrl = server.add('pinned.png', ServedFile(randomBytes(300 * 1024, seed: 1), contentType: 'image/png'));
    expect(await cache.pin(pinnedUrl), isTrue);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await cache.putFile('https://img.example/$i.jpg', randomBytes(300 * 1024, seed: i + 2), fileExtension: 'jpg');
    }
    final freed = await cache.trimToLimit();
    expect(freed, greaterThanOrEqualTo(3 * 300 * 1024));
    expect(await cache.getFileFromCache(pinnedUrl.toString()), isNotNull);
    expect(await cache.getFileFromCache('https://img.example/4.jpg'), isNotNull, reason: 'newest kept');
    expect(await cache.getFileFromCache('https://img.example/0.jpg'), isNull, reason: 'oldest evicted');
    expect(await cache.sizeBytes(), lessThanOrEqualTo(1024 * 1024 + 64 * 1024));
  });

  test('clearUnpinned keeps pinned covers and local-library artwork', () async {
    final cache = create();
    final localArt = File(p.join(paths.artworkCacheDir.path, 'album-hash.jpg'))..writeAsBytesSync(tinyPng);
    final pinnedUrl = server.add('keep.png', ServedFile(tinyPng, contentType: 'image/png'));
    await cache.pin(pinnedUrl);
    await cache.putFile('https://img.example/x.jpg', randomBytes(10000), fileExtension: 'jpg');
    final freed = await cache.clearUnpinned();
    expect(freed, greaterThanOrEqualTo(10000));
    expect(await cache.getFileFromCache('https://img.example/x.jpg'), isNull);
    expect(await cache.getFileFromCache(pinnedUrl.toString()), isNotNull);
    expect(localArt.existsSync(), isTrue);

    await cache.unpin(pinnedUrl);
    await cache.clearUnpinned();
    expect(await cache.getFileFromCache(pinnedUrl.toString()), isNull);
  });
}
