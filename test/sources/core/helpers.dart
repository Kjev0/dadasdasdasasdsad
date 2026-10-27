import 'dart:convert';
import 'dart:io';

import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/net/http_client.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/sources/base/music_source_base.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Reads a recorded API response from `test/sources/core/fixtures/`.
String fixture(String name) => File('test/sources/core/fixtures/$name').readAsStringSync();

Object? fixtureJson(String name) => jsonDecode(fixture(name));

http.Response jsonResponse(String body, {int status = 200, Map<String, String>? headers}) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
    );

/// A MockClient-backed [FermataHttp] that records every request.
class RecordingHttp {
  RecordingHttp(Future<http.Response> Function(http.Request request) handler) {
    client = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    fermata = FermataHttp(client: client, timeout: const Duration(seconds: 5));
  }

  late final MockClient client;
  late final FermataHttp fermata;
  final List<http.Request> requests = [];

  Uri get last => requests.last.url;
}

/// A configurable fake source for registry tests.
class FakeSource extends MusicSourceBase {
  FakeSource(
    this.id, {
    this.ready = true,
    this.caps = const {SourceCapability.searchTracks, SourceCapability.searchArtists},
    this.delay = Duration.zero,
    this.failWith,
    this.ignoreCancel = false,
  });

  @override
  final String id;
  bool ready;
  final Set<SourceCapability> caps;
  Duration delay;
  Object? failWith;
  final bool ignoreCancel;
  final List<String> calls = [];

  @override
  String get displayName => 'Fake $id';

  @override
  Set<SourceCapability> get capabilities => caps;

  @override
  String get limitationsNote => 'fake';

  @override
  bool get isReady => ready;

  void setAuth(SourceAuthState s) => emitAuthState(s);

  Future<void> _wait(CancelToken? cancel) async {
    if (delay == Duration.zero) return;
    if (ignoreCancel || cancel == null) return Future<void>.delayed(delay);
    await Future.any([Future<void>.delayed(delay), cancel.whenCanceled]);
    cancel.throwIfCanceled();
  }

  @override
  Future<Page<Track>> searchTracks(String query, {String? cursor, int limit = 30, CancelToken? cancel}) async {
    calls.add('tracks:$query');
    await _wait(cancel);
    if (failWith != null) throw failWith!;
    return Page([Track(sourceId: id, sourceTrackId: '1', title: '$query on $id')]);
  }

  @override
  Future<Page<Artist>> searchArtists(String query, {String? cursor, int limit = 20, CancelToken? cancel}) async {
    calls.add('artists:$query');
    await _wait(cancel);
    if (failWith != null) throw failWith!;
    return Page([Artist(sourceId: id, sourceArtistId: 'a', name: 'Artist $id')]);
  }
}
