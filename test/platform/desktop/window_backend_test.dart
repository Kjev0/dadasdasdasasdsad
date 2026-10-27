import 'package:fermata/platform/desktop/window/window_backend.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the real WindowManagerBackend against a mocked `window_manager`
/// platform channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getBounds':
          return {'x': 10.0, 'y': 20.0, 'width': 800.0, 'height': 600.0};
        case 'isMinimized' || 'isMaximized':
          return false;
        case 'isVisible':
          return true;
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> nativeEvent(String name) => messenger.handlePlatformMessage(
        'window_manager',
        const StandardMethodCodec().encodeMethodCall(MethodCall('onEvent', {'eventName': name})),
        (_) {},
      );

  test('forwards calls to window_manager', () async {
    final w = WindowManagerBackend();
    await w.ensureInitialized();
    await w.setPreventClose(true);
    await w.setTitle('Fermata');
    await w.setMinimumSize(const Size(380, 600));
    await w.setBounds(const Rect.fromLTWH(1, 2, 300, 400));
    expect(await w.getBounds(), const Rect.fromLTWH(10, 20, 800, 600));
    await w.hide();
    await w.show();
    await w.focus();
    await w.minimize();
    await w.destroy();
    final methods = calls.map((c) => c.method).toList();
    expect(methods, containsAllInOrder(['ensureInitialized', 'setPreventClose', 'setTitle', 'setMinimumSize', 'setBounds']));
    expect(methods, containsAllInOrder(['hide', 'show', 'focus', 'minimize', 'destroy']));
    expect(calls.firstWhere((c) => c.method == 'setPreventClose').arguments, {'isPreventClose': true});
    final bounds = calls.firstWhere((c) => c.method == 'setBounds').arguments as Map;
    expect([bounds['x'], bounds['y'], bounds['width'], bounds['height']], [1, 2, 300, 400]);
    await w.dispose();
  });

  test('turns native window events into WindowEventKind', () async {
    final w = WindowManagerBackend();
    await w.ensureInitialized();
    final events = <WindowEventKind>[];
    final sub = w.events.listen(events.add);
    for (final e in ['close', 'move', 'moved', 'resize', 'resized', 'maximize', 'minimize', 'restore', 'show', 'hide']) {
      await nativeEvent(e);
    }
    await Future<void>.delayed(Duration.zero);
    expect(events, [
      WindowEventKind.close,
      WindowEventKind.moved,
      WindowEventKind.moved,
      WindowEventKind.resized,
      WindowEventKind.resized,
      WindowEventKind.maximized,
      WindowEventKind.minimized,
      WindowEventKind.restored,
      WindowEventKind.shown,
      WindowEventKind.hidden,
    ]);
    await sub.cancel();
    await w.dispose();
  });

  test('display query failures yield no work areas', () async {
    final w = WindowManagerBackend();
    expect(await w.displayWorkAreas(), isEmpty); // no screen_retriever handler
  });
}
