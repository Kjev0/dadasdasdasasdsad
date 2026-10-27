// Adversarial review: signed download URLs (bearer credentials) must not end
// up in logs (docs/specs/_common.md: "Never log tokens/secrets").
import 'dart:async';

import 'package:fermata/core/models/download.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'support/harness.dart';
import 'support/test_server.dart';

void main() {
  late DownloadHarness h;
  final records = <LogRecord>[];
  StreamSubscription<LogRecord>? sub;

  setUp(() async {
    h = await DownloadHarness.start();
    records.clear();
    Logger.root.level = Level.ALL;
    sub = Logger.root.onRecord.listen(records.add);
  });
  tearDown(() async {
    await sub?.cancel();
    await h.dispose();
  });

  test('the query signature of a signed download URL is not logged when a download finally fails', () async {
    const secret = 'Sig-5ecr3t-0123456789';
    // Every attempt is cut off mid-body (flaky CDN) → the task fails after 5 attempts.
    final track = h.serve('signed', ServedFile(fakeMp3(64 * 1024), disconnectAfterBytes: 4096, disconnects: 100));
    final auth = h.auths['signed']!;
    h.auths['signed'] = DownloadAuthorization(
      uri: auth.uri.replace(queryParameters: {'X-Amz-Signature': secret, 'X-Amz-Expires': '900'}),
    );
    final m = h.create();
    await m.init();
    final task = await m.enqueue(track);
    final failed = await waitForStatus(m, task.id, DownloadStatus.failed, timeout: const Duration(seconds: 30));
    expect(failed.attempts, 5);

    final leaked = [
      for (final r in records)
        if ('${r.message} ${r.error}'.contains(secret)) '${r.loggerName} ${r.level}: ${r.message} ${r.error}',
    ];
    expect(leaked, isEmpty, reason: 'signed URL logged:\n${leaked.join('\n')}');
  });
}
