import 'package:air_swipe/data/swipe_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final binding = TestDefaultBinaryMessengerBinding.instance;
  final messenger = binding.defaultBinaryMessenger;

  SwipePlatform platformUnderTest() =>
      SwipePlatform(channel: const MethodChannel(SwipePlatform.channelName));

  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel(SwipePlatform.channelName),
      null,
    );
  });

  test('ShizukuStatus.fromArguments parses granted and running from a map', () {
    final status = ShizukuStatus.fromArguments(<Object?, Object?>{
      'granted': true,
      'running': false,
    });

    expect(status.granted, isTrue);
    expect(status.running, isFalse);
  });

  test('getShizukuStatus invokes the native method and parses the result', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(
      const MethodChannel(SwipePlatform.channelName),
      (call) async {
        received = call;
        return <Object?, Object?>{'granted': true, 'running': true};
      },
    );

    final status = await platformUnderTest().getShizukuStatus();

    expect(received?.method, 'getShizukuStatus');
    expect(status.granted, isTrue);
    expect(status.running, isTrue);
  });

  test('requestShizukuPermission relays the native call', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(
      const MethodChannel(SwipePlatform.channelName),
      (call) async {
        received = call;
        return <Object?, Object?>{'granted': false, 'running': true};
      },
    );

    final status = await platformUnderTest().requestShizukuPermission();

    expect(received?.method, 'requestShizukuPermission');
    expect(status.granted, isFalse);
    expect(status.running, isTrue);
  });

  test('listenCommands dispatches shizukuStatus pushes', () async {
    final statuses = <ShizukuStatus>[];
    platformUnderTest().listenCommands(
      onStart: () async {},
      onStop: () async {},
      onCameraError: (_) {},
      onHand: (_) async {},
      onShizukuStatus: statuses.add,
    );

    await binding.defaultBinaryMessenger.handlePlatformMessage(
      SwipePlatform.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('shizukuStatus', <Object?, Object?>{
          'granted': true,
          'running': true,
        }),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(statuses, hasLength(1));
    expect(statuses.single.granted, isTrue);
    expect(statuses.single.running, isTrue);
  });
}
